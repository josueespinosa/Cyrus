//
//  DatabaseHelper.swift
//  Cyrus
//
//  Created by Josue Espinosa on 12/23/17.
//  Copyright © 2017 Josue Espinosa. All rights reserved.
//

import Foundation
import SQLite3

class DatabaseHelper {
    static let databaseName = "chinook"
    static let databaseExtension = "db"
    static var documentDirectory: URL?
    static var database: OpaquePointer?
    static private var isReady = false

    static func createDatabase() {
        let fileManager = FileManager.default
        documentDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        documentDirectory!.appendPathComponent(databaseName + "." + databaseExtension)
        let fileExists = fileManager.fileExists(atPath: documentDirectory!.path)
        if !fileExists {
            let fromPath = Bundle.main.url(forResource: databaseName, withExtension: databaseExtension)
            do {
                try fileManager.copyItem(at: fromPath!, to: documentDirectory!)
            } catch {
                print(error)
            }
        }
    }

    static func openDatabase() {
        if sqlite3_open(documentDirectory!.path, &database) != SQLITE_OK {
            print(String(cString: sqlite3_errmsg(database)!))
        }
    }

    static func prepareDatabase() {
        if !isReady {
            createDatabase()
            openDatabase()
            isReady = true
        }
    }

    static func getTableNamesFromDatabase() -> [String] {
        let sql = "SELECT * FROM sqlite_master WHERE type='table' AND name NOT LIKE '%sqlite_%'"

        var statement: OpaquePointer?
        if sqlite3_prepare_v2(database, sql, -1, &statement, nil) != SQLITE_OK {
            print(String(cString: sqlite3_errmsg(database)!))
        }

        let columnNames = getAllColumnNamesFromTable(tableName: "sqlite_master")
        var nameColumnIndex = -1
        for i in 0...(columnNames.count - 1) {
            let columnName = columnNames[i].lowercased()
            if columnName == "name" {
                nameColumnIndex = i
                break
            }
        }

        var tableNames = [String]()

        while sqlite3_step(statement) == SQLITE_ROW {
            if let cString = sqlite3_column_text(statement, Int32(nameColumnIndex)) {
                let name = String(cString: cString)
                tableNames.append(name)
            }
        }

        if sqlite3_finalize(statement) != SQLITE_OK {
            print(String(cString: sqlite3_errmsg(database)!))
        }
        return tableNames
    }

    static func getAllColumnNamesFromTable(tableName: String) -> [String] {
        let sql = "SELECT * FROM \(tableName)"

        var statement: OpaquePointer?
        if sqlite3_prepare_v2(database, sql, -1, &statement, nil) != SQLITE_OK {
            print(String(cString: sqlite3_errmsg(database)!))
        }

        var columns = [String]()

        let columnCount = Int(sqlite3_column_count(statement))
        for i in 0...(columnCount - 1) {
            columns.append(String(cString: sqlite3_column_name(statement, Int32(i))))
        }

        if sqlite3_finalize(statement) != SQLITE_OK {
            print(String(cString: sqlite3_errmsg(database)!))
        }
        return columns
    }

    static func executeSql(sql: String) -> [String] {
        var statement: OpaquePointer?

        if sqlite3_prepare_v2(database, sql, -1, &statement, nil) != SQLITE_OK {
            print(String(cString: sqlite3_errmsg(database)!))
        }

        var rows = [String]()

        while sqlite3_step(statement) == SQLITE_ROW {

            let columnCount = Int(sqlite3_column_count(statement))
            var columnAndIndices = [String: Int]()
            for i in 0...columnCount-1 {
                let columnName = String(cString: sqlite3_column_name(statement, Int32(i)))
                columnAndIndices[columnName] = i
            }

            var result = ""
            for i in 0...(columnCount - 1) {
                let column = String(cString: sqlite3_column_name(statement, Int32(i)))
                result += column + ": "
                if let cString = sqlite3_column_text(statement, Int32(columnAndIndices[column]!)) {
                    let val = String(cString: cString)
                    if i != (columnCount - 1) {
                        result += val + ", "
                    } else {
                        result += val + ""
                    }
                }
            }
            rows.append(result)
        }

        if sqlite3_finalize(statement) != SQLITE_OK {
            print(String(cString: sqlite3_errmsg(database)!))
        }
        return rows
    }

    static func closeDatabase() {
        if sqlite3_close(database) != SQLITE_OK {
            print(String(cString: sqlite3_errmsg(database)!))
        }
    }
}
