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
#include <sqlite3.h>

using namespace std;

vector<string> split(const string& s, const char delim = ' ') {
    vector<std::string> sv;
    istringstream iss(s);
    string temp;

    while (getline(iss, temp, delim)) {
        sv.emplace_back(move(temp));
    }

    return sv;
}

string get_sql(vector<string> columns) {
    vector<string> rows;
    
    string code = columns[0];

    for (int i = 1; i < columns.size(); i++) {
        vector<string> row;
        row.push_back("'" + code + "'");
        row.push_back("'" + columns[i] + "'");
        string rowstr = "('" + code + "', '" + columns[i] + "')";
        rows.push_back(rowstr);
    }

    stringstream res;
    copy(rows.begin(), rows.end(), ostream_iterator<string>(res, ", "));
    return res.str();
}

void create_table(sqlite3 *db, string tableName = "dict_wb") {
    string sql = "create table if not exists " + tableName + "(" \
        "id integer primary key autoincrement not null, " \
        "code   char(10) not null," \
        "text   text    not null" \
    ")";
    int rc = sqlite3_exec(db, sql.c_str(), NULL, NULL, NULL);
    if (rc == SQLITE_OK) {
        cout<<"dict table created successfully"<<endl;
    } else {
        cout<<"dict table created failure: "<<sqlite3_errmsg(db) <<endl;
    }
    sql = "create index if not exists code_index on " + tableName + "(code)";
    rc = sqlite3_exec(db, sql.c_str(), NULL, NULL, NULL);
    if (rc == SQLITE_OK) {
        cout<<"dict table index created successfully"<<endl;
    } else {
        cout<<"dict table index created failure: "<<sqlite3_errmsg(db) <<endl;
    }
}


int main(int argc, const char * argv[]) {
    // insert code here...
    std::cout << "Hello, World!\n";
    
    ifstream infile;
    infile.open("/Users/marchyang/wb_table.txt", ios::in);
    
    vector<vector<string>> dict;
    
    string line;
    while(getline(infile, line)) {
        dict.emplace_back(split(line));
    }
    
    
    vector<string> rowstrs;
    
    for (auto line : dict) {
        rowstrs.push_back(get_sql(line));
    }
    
    

    sqlite3 *db;
    
    int err = sqlite3_open("/Users/marchyang/db.sqlite3", &db);
    
    if (err){
        cerr << "Can't open database: " << sqlite3_errmsg(db) << endl;
        exit(0);
    }
    
    create_table(db, "wb_table");
    
    cout << "count:" << rowstrs.size() << endl;
    
    // 分批插入
    int step = 100000;  //每次插入数量
    vector<string>::iterator begin = rowstrs.begin();
    for(int i = 0; i < rowstrs.size(); i+= step) {
        vector<string>::iterator start = begin + i;
        unsigned long length = rowstrs.size() - i > step ? step : rowstrs.size() - i;

        vector<string>::iterator end = start + length;

        stringstream res;
        copy(start, end, ostream_iterator<string>(res, " "));

        string sql = "insert into wb_table(code, text) values" + res.str();
        sql.pop_back();
        sql.pop_back();
        sql.pop_back();


        int rc = sqlite3_exec(db, sql.c_str(), NULL, NULL, NULL);
        if (rc == SQLITE_OK) {
            cout<<"insert successfully"<<endl;
        } else {
            cout<<"insert failure: "<<sqlite3_errmsg(db) <<endl;
        }
    }
    
    
    return 0;
}
