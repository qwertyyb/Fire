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
#include "SQLCipher/sqlite3.h"

#define MULTILINE(...) #__VA_ARGS__

using namespace std;

string dbPath;
string tableName;
string txtPath;

sqlite3 *db;

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
      query text not null\
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
}


int main(int argc, const char * argv[]) {
    // insert code here...
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
        /**
         * 第二个参数为txt文件路径
         * 第三个参数为table名字
         * 第四个参数为sqlite文件路径
         * */
        txtPath = argv[2];
        tableName = argv[3];
        dbPath = argv[4];
        
        open_database();
    }
    
    if (cmd == "--combine-dict" && argc == 5) {
        dbPath = argv[2];
        string py_dict = argv[3];
        string wb_dict = argv[4];
        
        open_database();
        
        build_wb_py_dict(py_dict, wb_dict);
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
    int step = 100000;  //每次插入数量
    int begin = 0;
    for(int i = 0; i < rowstrs.size(); i += step) {
        int start = begin + i;
        int length = rowstrs.size() - start < step ? rowstrs.size() - start : step;
        int end = start + length;

        string values;
        for (int j = start; j < end; j += 1) {
          if (j == start) {
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
