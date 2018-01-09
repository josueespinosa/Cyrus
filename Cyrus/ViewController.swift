//
//  ViewController.swift
//  Cyrus
//
//  Created by Josue Espinosa on 12/23/17.
//  Copyright © 2017 Josue Espinosa. All rights reserved.
//

import UIKit

class ViewController: UIViewController {

    @IBOutlet weak var statusLabel: UILabel!
    @IBOutlet weak var voiceQueryTextView: UITextView!
    @IBOutlet weak var sqliteQueryTextView: UITextView!
    @IBOutlet weak var resultsTextView: UITextView!
    @IBOutlet weak var recordButton: UIButton!

    private var isRecording = false
    private var isAuthorized = false

    private var databaseTableNames = [String]()

    private var latestVoiceQuery = ""

    override func viewDidLoad() {
        super.viewDidLoad()
        DatabaseHelper.prepareDatabase()
        databaseTableNames = DatabaseHelper.getTableNamesFromDatabase().map { $0.lowercased() }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if !isAuthorized {
            SpeechHelper.requestAuthorization(completion: { authorizationStatus in
                self.isAuthorized = (authorizationStatus == .authorized)
                self.recordButton.isEnabled = self.isAuthorized
                if !self.isAuthorized {
                    let alert = UIAlertController(title: "Error",
                                                  message: "Please grant Cyrus mic & speech recognition authorization.",
                                                  preferredStyle: UIAlertControllerStyle.alert)
                    alert.addAction(UIAlertAction(title: "Click", style: UIAlertActionStyle.default, handler: nil))
                    self.present(alert, animated: true, completion: nil)
                }
            })
        }
    }

    func updateVoiceTranscription(transcription: String) {
        latestVoiceQuery = transcription
        voiceQueryTextView.text = latestVoiceQuery
    }

    func convertVoiceQueryToSql() -> String {
        var words = latestVoiceQuery.components(separatedBy: " ")
        var wordSpliceIndices = [Int]()
        let tablesUsedInQuery = getKeywordsUsedInVoiceQuery(keywords: databaseTableNames,
                                                                tokenizedVoiceQuery: words,
                                                                delimiter: "_",
                                                                startIndex: 0,
                                                                endIndex: Swift.max(0, (words.count - 1)),
                                                                startingSpliceIndices: &wordSpliceIndices)
        // since we can't mutate the array during enumeration in getKeywordsUsedInVoiceQuery,
        // merge compound table names after finding them
        spliceWordsAtIndices(words: &words, delimiter: "_", indices: &wordSpliceIndices)

        // TODO: support more than 1 table for queries
        let mainTable = tablesUsedInQuery[0]
        let mainTableIndex = words.index(of: mainTable)!

        let mainTableColumns = DatabaseHelper.getAllColumnNamesFromTable(tableName: mainTable).map { $0.lowercased() }

        let columnsBeforeTable = getKeywordsUsedInVoiceQuery(keywords: mainTableColumns,
                                                                     tokenizedVoiceQuery: words,
                                                                     delimiter: "",
                                                                     startIndex: 0,
                                                                     endIndex: Swift.max(0, (mainTableIndex - 1)),
                                                                     startingSpliceIndices: &wordSpliceIndices)
        // merge compound column names before table name
        spliceWordsAtIndices(words: &words, delimiter: "", indices: &wordSpliceIndices)

        let columnsAfterTable = getKeywordsUsedInVoiceQuery(keywords: mainTableColumns,
                                                                    tokenizedVoiceQuery: words,
                                                                    delimiter: "",
                                                                    startIndex: Swift.min(mainTableIndex + 1, (words.count - 1)),
                                                                    endIndex: words.count - 1,
                                                                    startingSpliceIndices: &wordSpliceIndices)
        // merge compound column names after table name
        spliceWordsAtIndices(words: &words, delimiter: "", indices: &wordSpliceIndices)

        var columnsValuesAndTypesForWhereClause = [(String, String, String)]()

        if columnsAfterTable.count > 0 {
            // we saved the column names before the table name and already know the table name
            // keep everything after the table name for performance in future loops
            words = Array(words.suffix((words.count - 1) - mainTableIndex))
            let prunedVoiceQuery = words.joined(separator: " ")
            // we don't need parts of speech until assigning where clause stuff for number vs proper noun
            var tokenizedQueryAndPartsOfSpeech = NaturalLanguageParser.partsOfSpeech(text: prunedVoiceQuery)
            // .joinNames from our tagger to simplify things like ["Jimi", "Hendrix"] -> ["Jimi Hendrix"]
            words = tokenizedQueryAndPartsOfSpeech.map { $0.0.lowercased() }

            columnsValuesAndTypesForWhereClause = findValuesForWhereColumns(columns: columnsAfterTable,
                                                                       words: &words,
                                                                       tokenizedQueryAndPartsOfSpeech: &tokenizedQueryAndPartsOfSpeech)

        }

        // if no select columns specified, select all
        let selectColumns = (columnsBeforeTable.count > 0) ? columnsBeforeTable.joined(separator: ", ") : "*"
        var sql = "SELECT " + selectColumns + " "
        sql += "FROM " + mainTable
        if columnsValuesAndTypesForWhereClause.count > 0 {
            sql += " WHERE "
            for i in 0...(columnsValuesAndTypesForWhereClause.count - 1) {
                let item = columnsValuesAndTypesForWhereClause[i]
                if item.2 == NSLinguisticTag.number.rawValue {
                    sql += item.0 + " = " + item.1 + " AND "
                } else {
                    sql += item.0 + " LIKE " + "'" + item.1 + "'" + " AND " + "'"
                }

                if i == (columnsValuesAndTypesForWhereClause.count - 1) {
                    sql = String(sql.prefix((sql.count - 1) - " AND ".count))
                }
            }
        }

        return sql
    }

    func findValuesForWhereColumns(columns: [String],
                                   words: inout [String],
                                   tokenizedQueryAndPartsOfSpeech: inout [(String, String)]) -> [(String, String, String)] {
        var columnsAndValuesForWhereClause = [(String, String, String)]()
        let acceptableWhereClauseTagTypes: [NSLinguisticTag] = [.number, .placeName, .personalName, .organizationName]
        let acceptableWhereClauseTags = acceptableWhereClauseTagTypes.map { $0.rawValue }
        var incrementStepper = 1
        for column in columns {
            var foundOrExhausted = false
            while !foundOrExhausted {
                var columnIndex = words.index(of: column)!
                var searchIndex = columnIndex
                var checkedAtLeastOneSide = false
                // check left hand side first, since we're checking the left most where column,
                // it's impossible to steal from the adjacent right column from the left
                // because there's no extra where column to the left
                if (searchIndex - incrementStepper) >= 0 {
                    checkedAtLeastOneSide = true
                    // main table name was at hypothetical index -1, we truncated the select clauses and the table name, verify we're not going out of bounds
                    searchIndex -= incrementStepper
                    let partOfSpeech = tokenizedQueryAndPartsOfSpeech[searchIndex].1
                    if acceptableWhereClauseTags.contains(partOfSpeech) {
                        columnsAndValuesForWhereClause.append((column, words[searchIndex], partOfSpeech))
                        words.remove(at: searchIndex)
                        columnIndex = words.index(of: column)!
                        words.remove(at: columnIndex)
                        tokenizedQueryAndPartsOfSpeech.remove(at: searchIndex)
                        tokenizedQueryAndPartsOfSpeech.remove(at: columnIndex)
                        foundOrExhausted = true
                        continue
                    }
                }
                searchIndex = columnIndex
                if (searchIndex + incrementStepper) <= tokenizedQueryAndPartsOfSpeech.count - 1 {
                    checkedAtLeastOneSide = true
                    searchIndex += incrementStepper
                    let partOfSpeech = tokenizedQueryAndPartsOfSpeech[searchIndex].1
                    if acceptableWhereClauseTags.contains(partOfSpeech) {
                        columnsAndValuesForWhereClause.append((column, words[searchIndex], partOfSpeech))
                        words.remove(at: searchIndex)
                        columnIndex = words.index(of: column)!
                        words.remove(at: columnIndex)
                        tokenizedQueryAndPartsOfSpeech.remove(at: searchIndex)
                        tokenizedQueryAndPartsOfSpeech.remove(at: columnIndex)
                        foundOrExhausted = true
                        continue
                    }
                }
                if !checkedAtLeastOneSide {
                    foundOrExhausted = true
                    continue
                }
                incrementStepper += 1
            }
        }
        return columnsAndValuesForWhereClause
    }

    // try calling this when the situation arises, then callback with the starting index as the passed index + 1
    func spliceWordsAtIndex(words: inout [String], index: Int) {
        words[index] = words[index] + "_" + words[index + 1]
        words.remove(at: index + 1)
    }

    func spliceWordsAtIndices(words: inout [String], delimiter: String, indices: inout [Int]) {
        if indices.count > 0 {
            for i in 0...(indices.count - 1) {
                let index = indices[i]
                words[index] = words[index] + delimiter + words[index + 1]
                words.remove(at: index + 1)
            }
        }
    }

    func getKeywordsUsedInVoiceQuery(keywords: [String],
                                     tokenizedVoiceQuery: [String],
                                     delimiter: String,
                                     startIndex: Int,
                                     endIndex: Int,
                                     startingSpliceIndices: inout [Int]) -> [String] {
        var keyWordsUsedInQuery = [String]()
        for keyword in keywords {
            var lastWord = ""
            var checkNextWordForCompoundKeyword = false
            for i in startIndex...endIndex {
                let word = tokenizedVoiceQuery[i].lowercased()
                if checkNextWordForCompoundKeyword {
                    // TODO: work with any delimiter instead of hardcoding for "_"
                    // TODO: work for any compound length instead of hardcoding for 2 words
                    let compoundKeyword = lastWord + delimiter + word
                    if compoundKeyword == keyword {
                        startingSpliceIndices.append(i - 1)
                        keyWordsUsedInQuery.append(compoundKeyword)
                    }
                    lastWord = ""
                    checkNextWordForCompoundKeyword = false
                } else if keyword.contains(word) && keyword != word {
                    checkNextWordForCompoundKeyword = true
                    lastWord = word
                } else if Utilities.levenshteinDistance(firstWord: word, secondWord: keyword) <= 1 {
                    // account for single character differences for plural/singular keyword mistakes by the user
                    keyWordsUsedInQuery.append(keyword)
                    // TODO: replace the close word to the keyword in the tokenizedVoiceQuery array
                }
            }
        }
        return keyWordsUsedInQuery
    }

    @IBAction func recordButtonTapped(_ sender: Any) {
        if isRecording {
            SpeechHelper.stopRecordingSpeech()
            let sql = convertVoiceQueryToSql()
            sqliteQueryTextView.text = sql
            let results = DatabaseHelper.executeSql(sql: sql).joined(separator: " ")
            resultsTextView.text = results
            SpeechHelper.speak(transcript: results)
            statusLabel.text = "Cyrus (ready to listen)"
            recordButton.setTitle("Record", for: .normal)
        } else {
            SpeechHelper.stopSpeaking()
            SpeechHelper.recordSpeech(newTranscriptionAvailable: updateVoiceTranscription)
            statusLabel.text = "Cyrus (listening...)"
            voiceQueryTextView.text = ""
            recordButton.setTitle("Stop Recording", for: .normal)
        }

        isRecording = !isRecording
    }

}
