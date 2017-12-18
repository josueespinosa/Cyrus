//
//  DatabaseHelper.swift
//  Siri
//
//  Created by Josue Espinosa on 9/21/17.
//  Copyright © 2017 Josue Espinosa. All rights reserved.
//

import Foundation
import SQLite3

class DatabaseHelper {
    static let dbName = "chinook.db"
    static var documentsDbPath: URL?
    static var db: OpaquePointer?
    
    static func createDatabase() {
        let fm = FileManager.default
        
        documentsDbPath = fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
        documentsDbPath!.appendPathComponent(dbName)
        let fileExists = fm.fileExists(atPath: documentsDbPath!.path)
        
        if !fileExists {
            let fromPath = Bundle.main.url(forResource: "chinook", withExtension: "db")
            try! fm.copyItem(at: fromPath!, to: documentsDbPath!)
        }
    }
    
    static func openDatabase() {
        if sqlite3_open(documentsDbPath!.path, &db) != SQLITE_OK {
            print("error opening database")
        } else {
            print("successfully opened db")
        }
    }
    
    static func getTableNamesFromDatabase() -> [String] {
        var statement: OpaquePointer?
        
        if sqlite3_prepare_v2(db, "SELECT * FROM sqlite_master where type='table' and name not LIKE '%sqlite_%' ", -1, &statement, nil) != SQLITE_OK {
            let errmsg = String(cString: sqlite3_errmsg(db)!)
            print("error preparing select: \(errmsg)")
        }
        
        var tableNames = [String]()
        
        while sqlite3_step(statement) == SQLITE_ROW {
            if let cString = sqlite3_column_text(statement, 1) {
                let name = String(cString: cString)
                tableNames.append(name)
            }
        }
        
        if sqlite3_finalize(statement) != SQLITE_OK {
            let errmsg = String(cString: sqlite3_errmsg(db)!)
            print("error finalizing prepared statement: \(errmsg)")
        }
        
        statement = nil
        return tableNames
    }
    
    static func getAllColumnNamesFromTable(tableName: String) -> [String] {
        var statement: OpaquePointer?
        
        if sqlite3_prepare_v2(db, "SELECT * FROM \(tableName)", -1, &statement, nil) != SQLITE_OK {
            let errmsg = String(cString: sqlite3_errmsg(db)!)
            print("error preparing select: \(errmsg)")
        }
        
        var columns = [String]()
        
        let totalColumn = Int(sqlite3_column_count(statement))
        print(totalColumn)
        for i in 0...totalColumn-1 {
            columns.append(String(cString: sqlite3_column_name(statement, Int32(i))))
        }
        
        
        if sqlite3_finalize(statement) != SQLITE_OK {
            let errmsg = String(cString: sqlite3_errmsg(db)!)
            print("error finalizing prepared statement: \(errmsg)")
        }
        
        statement = nil
        return columns
    }
    
    static func getAllRowsForTable(table: String) -> [String] {
        var statement: OpaquePointer?
        
        if sqlite3_prepare_v2(db, "SELECT * FROM \(table)", -1, &statement, nil) != SQLITE_OK {
            let errmsg = String(cString: sqlite3_errmsg(db)!)
            print("error preparing select: \(errmsg)")
        }
        
        var rows = [String]()
        
        while sqlite3_step(statement) == SQLITE_ROW {
            let columnCount = Int(sqlite3_column_count(statement))
            var result = ""
            for i in 0...columnCount - 1 {
                let columnName = String(cString: sqlite3_column_name(statement, Int32(i)))
                result += columnName + ": "
                if let cString = sqlite3_column_text(statement, Int32(i)) {
                    let val = String(cString: cString)
                    if i != columnCount - 1 {
                        result += val + ", "
                    } else {
                        result += val + ""
                    }
                }
            }
            rows.append(result)
        }
        
        if sqlite3_finalize(statement) != SQLITE_OK {
            let errmsg = String(cString: sqlite3_errmsg(db)!)
            print("error finalizing prepared statement: \(errmsg)")
        }
        
        statement = nil
        return rows
    }
    
    static func executeSql(sql: String, columns: [String], table: String) -> [String] {
        var statement: OpaquePointer?
        
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) != SQLITE_OK {
            let errmsg = String(cString: sqlite3_errmsg(db)!)
            print("error preparing select: \(errmsg)")
        }
        
        var rows = [String]()
        
        while sqlite3_step(statement) == SQLITE_ROW {
            
            let columnCount = Int(sqlite3_column_count(statement))
            var columnAndIndices = [String:Int]()
            for column in columns {
                for i in 0...columnCount-1 {
                    let columnName = String(cString: sqlite3_column_name(statement, Int32(i)))
                    if column.lowercased() == columnName.lowercased() {
                        columnAndIndices[column] = i
                        break
                    }
                }
            }
            
            var result = ""
            for column in columns {
                result += column + ": "
                if let cString = sqlite3_column_text(statement, Int32(columnAndIndices[column]!)) {
                    let val = String(cString: cString)
                    if columns.index(of: column) != columns.count - 1 {
                        result += val + ", "
                    } else {
                        result += val + ""
                    }
                }
            }
            rows.append(result)
        }
        
        if sqlite3_finalize(statement) != SQLITE_OK {
            let errmsg = String(cString: sqlite3_errmsg(db)!)
            print("error finalizing prepared statement: \(errmsg)")
        }
        
        statement = nil
        return rows
    }
    
    static func executeWhereSql(selectColumns: [String], table: String, whereColumns: [String], whereValuesAndTypes: [(String, String)]) -> [String] {
        var statement: OpaquePointer?
        
        var sql = "SELECT " + selectColumns.joined(separator: ", ") + " FROM " + table
        
        for i in 0...whereColumns.count-1 {
            if i == 0 {
                " WHERE "
            }
            sql += whereColumns[i] + " = " + ((whereValuesAndTypes[i].1 == NSLinguisticTag.number.rawValue) ? whereValuesAndTypes[i].0 : "'" + whereValuesAndTypes[i].0 + "'")
            if i != whereColumns.count - 1 {
                sql += " AND "
            }
        }
        
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) != SQLITE_OK {
            let errmsg = String(cString: sqlite3_errmsg(db)!)
            print("error preparing select: \(errmsg)")
        }
        
        var rows = [String]()
        
        while sqlite3_step(statement) == SQLITE_ROW {
            
            let columnCount = Int(sqlite3_column_count(statement))
            var columnAndIndices = [String:Int]()
            for column in selectColumns {
                for i in 0...columnCount-1 {
                    let columnName = String(cString: sqlite3_column_name(statement, Int32(i)))
                    if column.lowercased() == columnName.lowercased() {
                        columnAndIndices[column] = i
                        break
                    }
                }
            }
            
            var result = ""
            for column in selectColumns {
                result += column + ": "
                if let cString = sqlite3_column_text(statement, Int32(columnAndIndices[column]!)) {
                    let val = String(cString: cString)
                    if selectColumns.index(of: column) != selectColumns.count - 1 {
                        result += val + ", "
                    } else {
                        result += val + ""
                    }
                }
            }
            rows.append(result)
        }
        
        if sqlite3_finalize(statement) != SQLITE_OK {
            let errmsg = String(cString: sqlite3_errmsg(db)!)
            print("error finalizing prepared statement: \(errmsg)")
        }
        
        statement = nil
        return rows
    }
    
    static func executeSelectAllWhereSql(sqlString: inout String, table: String, whereColumns: [String], whereValuesAndTypes: [(String, String)]) -> [String] {
        var statement: OpaquePointer?
        
        var sql = "SELECT * FROM " + table + " WHERE "
        
        for i in 0...whereColumns.count-1 {
            if (whereValuesAndTypes[i].1 == NSLinguisticTag.number.rawValue) {
                sql += whereColumns[i] + " = " + whereValuesAndTypes[i].0
            } else {
                sql += whereColumns[i] + " LIKE " + "'" + whereValuesAndTypes[i].0 + "'"
            }
            if i != whereColumns.count - 1 {
                sql += " AND "
            }
        }
        
        sqlString = sql
        
        print("YO BOI " + sql)
        
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) != SQLITE_OK {
            let errmsg = String(cString: sqlite3_errmsg(db)!)
            print("error preparing select: \(errmsg)")
        }
        
        var rows = [String]()
        
        while sqlite3_step(statement) == SQLITE_ROW {
            
            let columnCount = Int(sqlite3_column_count(statement))
            var result = ""
            for i in 0...columnCount - 1 {
                let columnName = String(cString: sqlite3_column_name(statement, Int32(i)))
                result += columnName + ": "
                if let cString = sqlite3_column_text(statement, Int32(i)) {
                    let val = String(cString: cString)
                    if i != columnCount - 1 {
                        result += val + ", "
                    } else {
                        result += val + ""
                    }
                }
            }
            rows.append(result)
        }
        
        if sqlite3_finalize(statement) != SQLITE_OK {
            let errmsg = String(cString: sqlite3_errmsg(db)!)
            print("error finalizing prepared statement: \(errmsg)")
        }
        
        statement = nil
        return rows
    }
    
    static func closeDatabase() {
        if sqlite3_close(db) != SQLITE_OK {
            print("error closing database")
        }
        
        db = nil
    }
}
