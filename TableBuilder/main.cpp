//
//  main.cpp
//  txt2sqlite
//
//  Created by 虚幻 on 2020/10/12.
//  Copyright © 2020 qwertyyb. All rights reserved.
//

#include <iostream>
#include <sstream>
#include <string>
#include <vector>
#include <fstream>
#include <regex>
#include <map>
#include <set>
#include "SQLCipher/sqlite3.h"

#define MULTILINE(...) #__VA_ARGS__

using namespace std;

string dbPath;
string tableName;
string txtPath;

sqlite3 *db;

// 按空白字符分割
vector<string> split(const string& s) {
    vector<std::string> sv;
    int i = 0;
    std::string ss;

    while (s[i] != '\0') {
        if (s[i] != ' ' && s[i] != '\t' && s[i] != '\r' && s[i] != '\n') {
            // Append the char to the temp string.
            ss += s[i];
        } else if (ss.size() > 0) {
            sv.emplace_back(ss);
            ss.clear();
        }
        i++;
    }
    
  if (ss.size() > 0) {
    sv.emplace_back(ss);
  }

    return sv;
}

// 按指定字符分割（最多 splits 次）
vector<string> split_by(const string& s, char delim, int maxSplits = -1) {
    vector<string> result;
    string cur;
    int splits = 0;
    for (char ch : s) {
        if (ch == delim && (maxSplits < 0 || splits < maxSplits)) {
            result.push_back(cur);
            cur.clear();
            splits++;
        } else {
            cur += ch;
        }
    }
    result.push_back(cur);
    return result;
}

string join(vector<string> arr, string sperator) {
  string values;
  for (int j = 0; j < arr.size(); j += 1) {
    if (j == 0) {
      values += arr[j];
    } else {
      values += (sperator + arr[j]);
    }
  }
  return values;
}

void open_database() {
    int err = sqlite3_open(dbPath.c_str(), &db);
    
    if (err){
        cerr << "Can't open database: " << sqlite3_errmsg(db) << endl;
        exit(0);
    }
}

string get_sql(vector<string> columns) {
    vector<string> rows;
    
    string code = columns[0];

    for (int i = 1; i < columns.size(); i++) {
        string rowstr = "('" + regex_replace(code, regex("'"), "") + "', '" + regex_replace(columns[i], regex("'"), "") + "')";
        rows.push_back(rowstr);
    }

    return join(rows, ",");
}

void create_table(sqlite3 *db, string tableName = "wb_dict") {
    string sql = "create table if not exists " + tableName + "(" \
        "id integer primary key autoincrement not null, " \
        "code   text not null," \
        "text   text    not null" \
    "); \
    insert into sqlite_sequence(name, seq) values('" + tableName + "', 100000)";
    int rc = sqlite3_exec(db, sql.c_str(), NULL, NULL, NULL);
    if (rc == SQLITE_OK) {
        cout<<"dict table created successfully"<<endl;
    } else {
        cout<<"dict table created failure: "<<sqlite3_errmsg(db) <<endl;
    }
    sql = "create index if not exists " + tableName + "_code_index on " + tableName + "(code)";
    rc = sqlite3_exec(db, sql.c_str(), NULL, NULL, NULL);
    if (rc == SQLITE_OK) {
        cout<<"dict table index created successfully"<<endl;
    } else {
        cout<<"dict table index created failure: "<<sqlite3_errmsg(db) <<endl;
        exit(2);
    }
}

void build_wb_py_dict(string py_dict, string wb_dict) {
    string createTable = "create table wb_py_dict (\
      id INTEGER PRIMARY KEY AUTOINCREMENT,\
      wbcode text not null,\
      text text not null,\
      type text not null,\
      query text not null,\
      version text default null,\
      s86 text default null,\
      s98 text default null,\
      s06 text default null,\
      py86 text default null,\
      py98 text default null,\
      py06 text default null,\
      is_gb2312 integer default 1\
    ); \
    insert into sqlite_sequence(name, seq) values('wb_py_dict', 100000)";
    
    int rc = sqlite3_exec(db, createTable.c_str(), NULL, NULL, NULL);
    if (rc == SQLITE_OK) {
        cout<<"dict wb_py_dict created successfully"<<endl;
    } else {
        cout<<"dict wb_py_dict created failure: "<<sqlite3_errmsg(db) <<endl;
        exit(1);
    }
    
    string sql = MULTILINE(
       insert into wb_py_dict(wbcode, text, type, query)
       select
         code as wbcode,
         text,
         'wb' as type,
         code as query
       from wb_dict;

       insert into wb_py_dict(wbcode, text, type, query)
       select
         wb.code as wbcode,
         py.text as text,
         'py' as type,
         py.code as query
       from
           py_dict py
         inner join
           wb_dict wb
         on py.text = wb.text
       order by py.id
    );
    
    rc = sqlite3_exec(db, sql.c_str(), NULL, NULL, NULL);
    if (rc == SQLITE_OK) {
        cout<<"initilize wb_py_dict created successfully"<<endl;
    } else {
        cout<<"initilize wb_py_dict created failure: "<<sqlite3_errmsg(db) <<endl;
        exit(1);
    }
    
    sql = "create index if not exists query_index on wb_py_dict(query)";
    rc = sqlite3_exec(db, sql.c_str(), NULL, NULL, NULL);
    if (rc == SQLITE_OK) {
        cout<<"create index success"<<endl;
    } else {
        cout<<"create index fail: "<<sqlite3_errmsg(db)<<endl;
        exit(1);
    }

    // text 列索引，供 merge_spelling 的 WHERE text=? 和 GROUP BY text 加速
    sql = "create index if not exists text_index on wb_py_dict(text)";
    rc = sqlite3_exec(db, sql.c_str(), NULL, NULL, NULL);
    if (rc == SQLITE_OK) {
        cout<<"create text index success"<<endl;
    } else {
        cout<<"create text index fail: "<<sqlite3_errmsg(db)<<endl;
    }
}

// 解析单个拼写文件行，提取关键字段
// 格式: 字符\t[※字形※...,※五笔码※,※拼音※,※关键字※]
struct SpellingEntry {
    string ch;
    string glyphs;
    string wbcode;
    string pinyin;
    bool is_gb2312;
};

SpellingEntry parse_spelling_line(const string& line) {
    SpellingEntry entry;
    entry.is_gb2312 = false;

    // 按制表符分割
    auto parts = split_by(line, '\t', 1);
    if (parts.size() < 2) return entry;
    entry.ch = parts[0];

    // 提取 [] 内的内容
    string data = parts[1];
    size_t lb = data.find('[');
    size_t rb = data.find(']');
    if (lb == string::npos || rb == string::npos || lb >= rb) return entry;
    data = data.substr(lb + 1, rb - lb - 1);

    // 按逗号分割字段
    auto fields = split_by(data, ',');
    if (fields.empty()) return entry;

    // 字段0: 拆字字形，去除※
    string raw_glyphs = fields[0];
    string target = "※";
    size_t pos = 0;
    while ((pos = raw_glyphs.find(target, pos)) != string::npos) {
        raw_glyphs.erase(pos, target.length());
    }
    entry.glyphs = raw_glyphs;

    // 字段1: 五笔码，去除※
    if (fields.size() >= 2) {
        string wb = fields[1];
        string target = "※";
        size_t pos = 0;
        while ((pos = wb.find(target, pos)) != string::npos) {
            wb.erase(pos, target.length());
        }
        entry.wbcode = wb;
    }

    // 字段2: 拼音
    if (fields.size() >= 3) {
        string py = fields[2];
        string target = "※";
        size_t pos = 0;
        while ((pos = py.find(target, pos)) != string::npos) {
            py.erase(pos, target.length());
        }
        entry.pinyin = py;
    }

    // 字段3: 关键字
    if (fields.size() >= 4) {
        entry.is_gb2312 = fields[3].find("GB2312") != string::npos;
    }

    return entry;
}

// 读取拼写文件为 map<char, SpellingEntry>
map<string, SpellingEntry> load_spelling_file(const string& path) {
    map<string, SpellingEntry> result;
    ifstream infile(path);
    if (!infile.is_open()) {
        cerr << "spelling file not found: " << path << endl;
        return result;
    }
    string line;
    int count = 0;
    while (getline(infile, line)) {
        auto entry = parse_spelling_line(line);
        if (!entry.ch.empty()) {
            result[entry.ch] = entry;
            count++;
        }
    }
    cout << "loaded " << count << " entries from " << path << endl;
    return result;
}

// 合并拼写数据到 wb_py_dict（批量方式）
void merge_spelling(const string& s86_path, const string& s98_path, const string& s06_path) {
    auto s86 = load_spelling_file(s86_path);
    auto s98 = load_spelling_file(s98_path);
    auto s06 = load_spelling_file(s06_path);

    // 合并所有汉字，构建行数据
    // 行格式: ch, version, wbcode, glyph86, glyph98, glyph06, py86, py98, py06, gb
    vector<vector<string>> rows;
    set<string> all_chars;
    for (auto& kv : s86) all_chars.insert(kv.first);
    for (auto& kv : s98) all_chars.insert(kv.first);
    for (auto& kv : s06) all_chars.insert(kv.first);

    for (const string& ch : all_chars) {
        auto it86 = s86.find(ch);
        auto it98 = s98.find(ch);
        auto it06 = s06.find(ch);

        string g86 = it86 != s86.end() ? it86->second.glyphs : "";
        string g98 = it98 != s98.end() ? it98->second.glyphs : "";
        string g06 = it06 != s06.end() ? it06->second.glyphs : "";

        string py86 = it86 != s86.end() ? it86->second.pinyin : "";
        string py98 = it98 != s98.end() ? it98->second.pinyin : "";
        string py06 = it06 != s06.end() ? it06->second.pinyin : "";

        string wb86 = it86 != s86.end() ? it86->second.wbcode : "";
        string wb98 = it98 != s98.end() ? it98->second.wbcode : "";
        string wb06 = it06 != s06.end() ? it06->second.wbcode : "";

        int gb = 0;
        if ((it86 != s86.end() && it86->second.is_gb2312) ||
            (it98 != s98.end() && it98->second.is_gb2312) ||
            (it06 != s06.end() && it06->second.is_gb2312)) {
            gb = 1;
        }

        // 取任一版本编码作为插入时的备用
        string wb = !wb86.empty() ? wb86 : !wb98.empty() ? wb98 : wb06;
        string ver = !wb86.empty() ? "86" : !wb98.empty() ? "98" : "06";

        rows.push_back({ch, ver, wb, g86, g98, g06, py86, py98, py06, to_string(gb)});
    }
    cout << "total unique chars: " << rows.size() << endl;

    // 开启事务
    sqlite3_exec(db, "BEGIN TRANSACTION", NULL, NULL, NULL);

    // 1. 创建临时表并批量插入所有拼写数据
    sqlite3_exec(db,
        "create temp table sp(ch text primary key, ver text, wbcode text, "
        "g86 text, g98 text, g06 text, py86 text, py98 text, py06 text, gb int)", NULL, NULL, NULL);

    sqlite3_stmt *ins;
    sqlite3_prepare_v2(db,
        "insert into sp values(?1,?2,?3,?4,?5,?6,?7,?8,?9,?10)", -1, &ins, NULL);

    for (auto& r : rows) {
        sqlite3_reset(ins);
        for (int i = 0; i < 10; i++) {
            sqlite3_bind_text(ins, i + 1, r[i].c_str(), -1, SQLITE_TRANSIENT);
        }
        sqlite3_step(ins);
    }
    sqlite3_finalize(ins);
    cout << "temp table populated" << endl;

    // 2. 批量 UPDATE 已有行
    string update_sql =
        "update wb_py_dict set "
        "s86 = coalesce((select g86 from sp where sp.ch = wb_py_dict.text), s86), "
        "s98 = coalesce((select g98 from sp where sp.ch = wb_py_dict.text), s98), "
        "s06 = coalesce((select g06 from sp where sp.ch = wb_py_dict.text), s06), "
        "py86 = coalesce((select py86 from sp where sp.ch = wb_py_dict.text), py86), "
        "py98 = coalesce((select py98 from sp where sp.ch = wb_py_dict.text), py98), "
        "py06 = coalesce((select py06 from sp where sp.ch = wb_py_dict.text), py06), "
        "is_gb2312 = (select gb from sp where sp.ch = wb_py_dict.text) "
        "where text in (select ch from sp)";
    sqlite3_exec(db, update_sql.c_str(), NULL, NULL, NULL);
    int updated = sqlite3_changes(db);
    cout << "updated: " << updated << endl;

    // 3. 批量 INSERT 缺失行
    string insert_sql =
        "insert into wb_py_dict(wbcode, text, type, query, version, s86, s98, s06, py86, py98, py06, is_gb2312) "
        "select sp.wbcode, sp.ch, 'wb', sp.wbcode, sp.ver, "
        "nullif(sp.g86,''), nullif(sp.g98,''), nullif(sp.g06,''), "
        "nullif(sp.py86,''), nullif(sp.py98,''), nullif(sp.py06,''), sp.gb "
        "from sp left join wb_py_dict on sp.ch = wb_py_dict.text "
        "where wb_py_dict.text is null";
    sqlite3_exec(db, insert_sql.c_str(), NULL, NULL, NULL);
    int inserted = sqlite3_changes(db);
    cout << "inserted: " << inserted << endl;

    sqlite3_exec(db, "END TRANSACTION", NULL, NULL, NULL);
    cout << "merge spelling done" << endl;

    // 4. 预计算多字词的组合拆字
    cout << "pre-computing phrase spellings..." << endl;
    sqlite3_exec(db, "BEGIN TRANSACTION", NULL, NULL, NULL);

    // 查询所有多字词行
    sqlite3_stmt *phrase_stmt;
    sqlite3_prepare_v2(db,
        "select distinct text from wb_py_dict where length(text) > 1", -1, &phrase_stmt, NULL);

    sqlite3_stmt *ph_update;
    sqlite3_prepare_v2(db,
        "update wb_py_dict set s86=?1, s98=?2, s06=?3, py86=?4, py98=?5, py06=?6 where text=?7", -1, &ph_update, NULL);

    // 取单字的 sp 数据
    auto get_glyph = [&](const string& ch, const string& col) -> string {
        sqlite3_stmt* st;
        string sql = "select " + col + " from sp where ch = ?";
        sqlite3_prepare_v2(db, sql.c_str(), -1, &st, NULL);
        sqlite3_bind_text(st, 1, ch.c_str(), -1, SQLITE_TRANSIENT);
        string result;
        if (sqlite3_step(st) == SQLITE_ROW) {
            const char* cstr = (const char*)sqlite3_column_text(st, 0);
            if (cstr) result = cstr;
        }
        sqlite3_finalize(st);
        return result;
    };

    // 按组词规则取前 n 个字形
    auto prefix_n = [&](const string& ch, int n, const string& col) -> string {
        string g = get_glyph(ch, col);
        if (g.empty() || (size_t)n > g.size()) return "";
        // 取前 n 个 UTF-8 字符
        int count = 0;
        string r;
        for (size_t i = 0; i < g.size() && count < n; ) {
            unsigned char c = g[i];
            int len = (c & 0x80) == 0 ? 1 : (c & 0xE0) == 0xC0 ? 2 :
                      (c & 0xF0) == 0xE0 ? 3 : 4;
            r += g.substr(i, len);
            i += len;
            count++;
        }
        return r;
    };

    int phrase_count = 0;
    while (sqlite3_step(phrase_stmt) == SQLITE_ROW) {
        string text = (const char*)sqlite3_column_text(phrase_stmt, 0);
        // 拆成单字
        vector<string> chars;
        for (size_t i = 0; i < text.size(); ) {
            unsigned char c = text[i];
            int len = (c & 0x80) == 0 ? 1 : (c & 0xE0) == 0xC0 ? 2 :
                      (c & 0xF0) == 0xE0 ? 3 : 4;
            chars.push_back(text.substr(i, len));
            i += len;
        }
        if (chars.size() < 2) continue;

        // 分别为 s86/s98/s06 和 py86/py98/py06 计算组合拆字和拼音
        string result[6] = {"", "", "", "", "", ""};
        string gcols[3] = {"g86", "g98", "g06"};
        string pycols[3] = {"py86", "py98", "py06"};
        for (int ci = 0; ci < 3; ci++) {
            // 拆字组合
            vector<string> glyphs;
            for (auto& ch : chars) {
                string g = get_glyph(ch, gcols[ci]);
                if (g.empty()) { glyphs.clear(); break; }
                glyphs.push_back(g);
            }
            if (!glyphs.empty()) {
                string r;
                if (chars.size() == 2) {
                    r = prefix_n(chars[0], 2, gcols[ci]) + prefix_n(chars[1], 2, gcols[ci]);
                } else if (chars.size() == 3) {
                    r = prefix_n(chars[0], 1, gcols[ci]) + prefix_n(chars[1], 1, gcols[ci])
                        + prefix_n(chars[2], 2, gcols[ci]);
                } else {
                    r = prefix_n(chars[0], 1, gcols[ci]) + prefix_n(chars[1], 1, gcols[ci])
                        + prefix_n(chars[2], 1, gcols[ci]) + prefix_n(chars.back(), 1, gcols[ci]);
                }
                if (!r.empty()) result[ci] = r;
            }

            // 拼音组合（直接拼接，用空格分隔）
            vector<string> pinyins;
            for (auto& ch : chars) {
                string p = get_glyph(ch, pycols[ci]);
                if (p.empty()) { pinyins.clear(); break; }
                pinyins.push_back(p);
            }
            if (!pinyins.empty()) {
                string r;
                for (size_t j = 0; j < pinyins.size(); j++) {
                    if (j > 0) r += "，";
                    r += pinyins[j];
                }
                result[ci + 3] = r;
            }
        }
        if (result[0].empty() && result[1].empty() && result[2].empty() &&
            result[3].empty() && result[4].empty() && result[5].empty()) continue;

        sqlite3_reset(ph_update);
        for (int ci = 0; ci < 6; ci++) {
            if (result[ci].empty())
                sqlite3_bind_null(ph_update, ci + 1);
            else
                sqlite3_bind_text(ph_update, ci + 1, result[ci].c_str(), -1, SQLITE_TRANSIENT);
        }
        sqlite3_bind_text(ph_update, 7, text.c_str(), -1, SQLITE_TRANSIENT);
        sqlite3_step(ph_update);
        phrase_count++;
    }
    sqlite3_finalize(phrase_stmt);
    sqlite3_finalize(ph_update);
    sqlite3_exec(db, "END TRANSACTION", NULL, NULL, NULL);
    cout << "phrase spellings updated: " << phrase_count << endl;
}

int main(int argc, const char * argv[]) {
    std::cout << "Hello, World!\n";
    
    cout << "argc: " << argc << endl;
  
  if (argc <= 1) {
    return 0;
  }
    
    for (int i = 0; i < argc; i++) {
        cout << "argv(" << i << "): " << argv[i] << endl;
    }
    string cmd = "";
    
    if (argc > 1) {
        cmd = argv[1];
    }
    
    if (cmd == "--create-dict" && argc == 5) {
        txtPath = argv[2];
        tableName = argv[3];
        dbPath = argv[4];
        
        open_database();
    }
    
    if (cmd == "--combine-dict" && argc == 5) {
        dbPath = argv[2];
        string wb_table = argv[3];
        string py_table = argv[4];
        
        open_database();
        
        build_wb_py_dict(wb_table, py_table);
        sqlite3_close(db);
        return 0;
    }
    
    if (cmd == "--merge-spelling" && argc == 6) {
        dbPath = argv[2];
        string s86_path = argv[3];
        string s98_path = argv[4];
        string s06_path = argv[5];

        open_database();

        merge_spelling(s86_path, s98_path, s06_path);

        sqlite3_close(db);
        return 0;
    }

    if (cmd == "--build-all" && argc == 8) {
        dbPath = argv[2];
        string wb_table = argv[3];
        string py_table = argv[4];
        string s86_path = argv[5];
        string s98_path = argv[6];
        string s06_path = argv[7];

        open_database();

        build_wb_py_dict(wb_table, py_table);
        merge_spelling(s86_path, s98_path, s06_path);

        sqlite3_close(db);
        return 0;
    }
    
    ifstream infile;
    infile.open(txtPath, ios::in);
    
    vector<vector<string>> dict;
    
    string line;
    while(getline(infile, line)) {
        dict.emplace_back(split(line));
    }
    
    vector<string> rowstrs;
    
    for (auto line : dict) {
        rowstrs.push_back(get_sql(line));
    }
    
    create_table(db, tableName);
    
    cout << "line count:" << rowstrs.size() << endl;
    
    // 分批插入
    int step = 100000;
    size_t rowCount = rowstrs.size();
    for(size_t i = 0; i < rowCount; i += step) {
        size_t length = (rowCount - i < (size_t)step) ? rowCount - i : step;
        size_t end = i + length;

        string values;
        for (size_t j = i; j < end; j += 1) {
          if (j == i) {
            values += rowstrs[j];
          } else {
            values += (',' + rowstrs[j]);
          }
        }

        string sql = "insert into " + tableName + "(code, text) values" + values;

        int rc = sqlite3_exec(db, sql.c_str(), NULL, NULL, NULL);
        if (rc == SQLITE_OK) {
            cout<<"insert successfully"<<endl;
        } else {
            cout<<"insert failure: "<<sqlite3_errmsg(db) <<endl;
            exit(1);
        }
    }
    
    sqlite3_close(db);
    return 0;
}
