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

vector<string> split(const string& s, const char delim = ' ') {
    vector<std::string> sv;
    istringstream iss(s);
    string temp;

    while (getline(iss, temp, delim)) {
        sv.emplace_back(move(temp));
    }

    return sv;
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
//        vector<string> row;
//        row.push_back("'" +  + "'");
//        row.push_back("'" + regex_replace(columns[i], regex("'"), "\'") + "'");
        string rowstr = "('" + regex_replace(code, regex("'"), "") + "', '" + regex_replace(columns[i], regex("'"), "") + "')";
        rows.push_back(rowstr);
    }

    stringstream res;
    copy(rows.begin(), rows.end(), ostream_iterator<string>(res, ", "));
    return res.str();
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
    vector<string>::iterator begin = rowstrs.begin();
    for(int i = 0; i < rowstrs.size(); i += step) {
        vector<string>::iterator start = begin + i;
        unsigned long length = rowstrs.size() - i > step ? step : rowstrs.size() - i;

        vector<string>::iterator end = start + length;

        stringstream res;
        copy(start, end, ostream_iterator<string>(res, " "));

        string sql = "insert into " + tableName + "(code, text) values" + res.str();
        sql.pop_back();
        sql.pop_back();
        sql.pop_back();

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
