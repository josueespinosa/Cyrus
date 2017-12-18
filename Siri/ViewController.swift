//
//  ViewController.swift
//  Siri
//
//  Created by Josue Espinosa on 9/21/17.
//  Copyright © 2017 Josue Espinosa. All rights reserved.
//

import UIKit
import Speech

class ViewController: UIViewController, SFSpeechRecognizerDelegate, SFSpeechRecognitionTaskDelegate {
	
	@IBOutlet weak var verbalTextView: UITextView!
	@IBOutlet weak var microphoneButton: UIButton!
    @IBOutlet weak var sqlTextView: UITextView!
    
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))!
    
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    // Create a new audio session
    private let audioSession = AVAudioSession.sharedInstance()
    private let speechSynthesizer = AVSpeechSynthesizer()
    
    var tableNames = [String]()
    
	override func viewDidLoad() {
        super.viewDidLoad()
        
        DatabaseHelper.createDatabase()
        DatabaseHelper.openDatabase()
        tableNames = DatabaseHelper.getTableNamesFromDatabase()
//        closeDatabase()
        
        microphoneButton.isEnabled = false
        speechRecognizer.delegate = self
        
        SFSpeechRecognizer.requestAuthorization { (authStatus: SFSpeechRecognizerAuthorizationStatus) in
            
            DispatchQueue.main.async {
                switch authStatus {
                case .authorized:
                    self.microphoneButton.isEnabled = true
                case .denied:
                    self.microphoneButton.isEnabled = false
                    self.microphoneButton.setTitle("User denied access to speech recognition", for: .disabled)
                case .restricted:
                    self.microphoneButton.isEnabled = false
                    self.microphoneButton.setTitle("Speech recognition restricted on this device", for: .disabled)
                case .notDetermined:
                    self.microphoneButton.isEnabled = false
                    self.microphoneButton.setTitle("Speech recognition not yet authorized", for: .disabled)
                }
            }
        }

	}

	@IBAction func microphoneTapped(_ sender: AnyObject) {
        if audioEngine.isRunning {
            audioEngine.stop()
            recognitionRequest?.endAudio()
            microphoneButton.isEnabled = false
            microphoneButton.setTitle("Start", for: .normal)
            
            do {
                try audioSession.setCategory(AVAudioSessionCategoryPlayback)
                try audioSession.setMode(AVAudioSessionModeSpokenAudio)
                try audioSession.setActive(false)
            } catch {
                print("audioSession properties weren't set because of an error.")
            }
            
        } else {
            if speechSynthesizer.isSpeaking {
                speechSynthesizer.stopSpeaking(at: .immediate)
            }
            startRecording()
            microphoneButton.setTitle("Stop", for: .normal)
        }
	}
    
    func startRecording() {
        
        // Cancel the previous task if it's running
        if recognitionTask != nil {
            recognitionTask?.cancel()
            recognitionTask = nil
        }
        
        do {
            try audioSession.setCategory(AVAudioSessionCategoryRecord)
            try audioSession.setMode(AVAudioSessionModeMeasurement)
            try audioSession.setActive(true, with: .notifyOthersOnDeactivation)
        } catch {
            print("audioSession properties weren't set because of an error.")
        }
        
        // Create a new live recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        
        // Get the audio engine input node
        let inputNode = audioEngine.inputNode
        
        guard let recognitionRequest = recognitionRequest else {
            fatalError("Unable to create an SFSpeechAudioBufferRecognitionRequest object")
        }
        
        // Configure request so that results are returned before audio recording is finished
        recognitionRequest.shouldReportPartialResults = true
        
        // A recognition task represents a speech recognition session.
        // We keep a reference to the task so that it can be cancelled.
        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest, resultHandler: { (result, error) in
            
            var isFinal = false
            
            // When the recognizer returns a result, we pass it to
            // the linguistic tagger to analyze its content.
            if let result = result {
                let sentence = result.bestTranscription.formattedString
                self.verbalTextView.text = sentence
                isFinal = result.isFinal
                if error != nil || isFinal {
//                    let lemmatizedSentence = NaturalLanguageParser.lemmatize(text: sentence)
                    var deconstructedSentence = NaturalLanguageParser.partsOfSpeech(text: sentence)
//                    if deconstructedSentence.count == 0 {
                        // make deconstructed sentence = original sentence
//                    }
//                    print("sentence: " + sentence)
//                    print("lemmatized sentence: " + lemmatizedSentence)
//                    print("deconstructed sentence: " + String(describing: deconstructedSentence))
                    var tableNamesUsedInQuery = [String]()
                    var firstWordForSplicingTwoPartTables = [String]()
                    for tableName in self.tableNames {
                        var lastWord = ""
                        var checkNextWordForCompoundTableName = false
                        for (word, partOfSpeech) in deconstructedSentence {
//                            // account for plurals e.g. Artists/Artist
//                            print("word: " + word)
//                            print("table name: " + tableName)
//                            print("last word: " + lastWord)
//                            print("check next word: " + String(describing: checkNextWordForCompoundTableName))
                            if checkNextWordForCompoundTableName {
                                if (lastWord.lowercased() + "_" + word.lowercased()) == tableName.lowercased() {
                                    firstWordForSplicingTwoPartTables.append(lastWord)
                                    tableNamesUsedInQuery.append(tableName)
                                }
                                lastWord = ""
                                checkNextWordForCompoundTableName = false
                            } else if tableName.lowercased().contains(word.lowercased()) && tableName.lowercased() != word.lowercased() {
                                checkNextWordForCompoundTableName = true
                                lastWord = word
                            } else if Utilities.levenshteinDistance(a: word, b: tableName) <= 1 {
                                print("TRUE")
                                tableNamesUsedInQuery.append(tableName)
                            }
                        }
                    }
                    print(tableNamesUsedInQuery.joined())
                    
                    var indexOfFirstTableOccurrence = 0
                    var deconstructedWords: [String] = deconstructedSentence.map({ $0.0.lowercased() })
                    
                    if tableNamesUsedInQuery.count > 0 {
                        
                        if firstWordForSplicingTwoPartTables.count > 0 {
                            // we have to splice the two part columns into a single word
                            for i in 0...firstWordForSplicingTwoPartTables.count-1 {
                                let j = deconstructedWords.index(of: firstWordForSplicingTwoPartTables[i])!
                                deconstructedSentence[j] = (deconstructedWords[j].lowercased() + "_" + deconstructedWords[j+1].lowercased(), "Noun")
                                deconstructedSentence.remove(at: j + 1)
                                deconstructedWords[j] = deconstructedWords[j].lowercased() + "_" + deconstructedWords[j+1].lowercased()
                                deconstructedWords.remove(at: j + 1)
                            }
                        }
                        indexOfFirstTableOccurrence = deconstructedWords.index(of: tableNamesUsedInQuery[0])!
                    }
                    
                    var prunedDeconstructedSentence = deconstructedSentence.suffix(from: indexOfFirstTableOccurrence)
                    
                    print("Before columns: " + String(describing: prunedDeconstructedSentence))
                    
                    // everything before the first table name can be removed, I can't think of a single
                    // type of query where the type of query can be changed by things prefixed before the from clause
                    // except selecting specific columns only
                    // we'll create a tmp without anything before the first table
                    // then we'll check if there were column names before the first table,
                    // if so,
                    // use those columns only for the select
                    
                    // e.g. yo cyrus could you help me find the names and ids of all the tracks composed by Jim Croce
                    
                    // tmp array is tracks composed by Jim Croce
                    
                    // column name loop goes up to index of first table and picks up columns for that table
                    // so we have
                    // names ids tracks composed by jim croce
                    
                    // (columnname, tablename)
                    var tablesAndColumnsUsedInQuery = [String: [String]]()
                    var columnNamesUsedInQuery = [String]()
                    var firstWordForSplicingTwoPartColumns = [String]()
                    for tableName in tableNamesUsedInQuery {
                        let columnNames = DatabaseHelper.getAllColumnNamesFromTable(tableName: tableName).map({$0.lowercased()})
                        for columnName in columnNames {
                            var lastWord = ""
                            var checkNextWordForCompoundColumnName = false
                            for (word, partOfSpeech) in deconstructedSentence {
                                // account for plurals e.g. Songs/Song
                                if checkNextWordForCompoundColumnName {
                                    if columnName.lowercased().contains(word.lowercased()) {
                                        // prior column name contains the prior word and the next word, it's likely something like Employee Id -> employeeId
                                        // TODO: allow for specifying database schema delimiters like "-","","_" -> employee-id, employeeId, employee_id
                                        // TODO: multiple word column names?
                                        // if exact match for column
                                        if (lastWord + word).lowercased() == columnName.lowercased() {
                                            firstWordForSplicingTwoPartColumns.append(lastWord)
                                            columnNamesUsedInQuery.append(lastWord.lowercased() + word.lowercased())
                                        }
                                        lastWord = ""
                                        checkNextWordForCompoundColumnName = false
                                    }
                                } else if columnName.lowercased().contains(word.lowercased()) && columnName.lowercased() != word.lowercased() {
                                    // could be case of FirstName, with words first and name being separate
//                                    lastWord = (word.prefix(1).capitalized + word.dropFirst())
                                    lastWord = word
                                    // sql is case-insensitive for columnnames
                                    // our particular schema has keys as FirstName, etc
                                    // TODO: make more robust/extensible
                                    checkNextWordForCompoundColumnName = true
                                } else if Utilities.levenshteinDistance(a: word, b: columnName) <= 1 {
                                    columnNamesUsedInQuery.append(word)
                                }
                            }
                        }
                        tablesAndColumnsUsedInQuery[tableName] = columnNamesUsedInQuery
                    }
                    
                    
                    var indexOfFirstColumnOccurrence = 0
                    
                    if columnNamesUsedInQuery.count > 0 {
                        if firstWordForSplicingTwoPartColumns.count > 0 {
                            // we have to splice the two part columns into a single word
                            for i in 0...firstWordForSplicingTwoPartColumns.count-1 {
                                let j = deconstructedWords.index(of: firstWordForSplicingTwoPartColumns[i])!
                                deconstructedSentence[j] = (deconstructedWords[j].lowercased() + deconstructedWords[j+1].lowercased(), deconstructedSentence[j].1)
                                deconstructedSentence.remove(at: j + 1)
                                deconstructedWords[j] = deconstructedWords[j].lowercased() + deconstructedWords[j+1].lowercased()
                                deconstructedWords.remove(at: j + 1)
                            }
                        }
                        indexOfFirstColumnOccurrence = deconstructedWords.index(of: columnNamesUsedInQuery[0])!
                    }
                    
                    if tableNamesUsedInQuery.count == 1 && tablesAndColumnsUsedInQuery[tableNamesUsedInQuery[0]]!.count == 0 {
                        // first possibility, only recognized word is a single table name
                        // if the only recognized text is a table name, select * from that table name
                        self.sqlTextView.text = "\"" + sentence + "\"" + "\n\n=\n\n" + "SELECT * FROM " + tableNamesUsedInQuery[0]
                        self.verbalTextView.text = DatabaseHelper.getAllRowsForTable(table: tableNamesUsedInQuery[0]).joined(separator: ".\n\n")
                    } else if indexOfFirstColumnOccurrence < indexOfFirstTableOccurrence {
                        // there were columns in the query, as well as tables
                        // recover columns used at the beginning of query
                        // likely formatted something like
                        // unnecessary junk columnName columnName trash from tableName where conditions
                        
                        var columnsAppearingBeforeFirstTable = [deconstructedSentence[indexOfFirstColumnOccurrence]]
                        
                        var columnsAppearBeforeFirstTable = true
                        
                        var indexOfColumnInDeconstructedSentenceArray = indexOfFirstColumnOccurrence
                        var columnNameArrayIndex = 0
                        while columnsAppearBeforeFirstTable {
                            if columnNameArrayIndex < (columnNamesUsedInQuery.count - 1) {
                                columnNameArrayIndex += 1
                                // when .suffix() is used, indices don't get reset to zero, they start relative to the suffix where they where cut off
                                // e.g. if you do suffix at 2, the first index is 2
                                indexOfColumnInDeconstructedSentenceArray = deconstructedWords.index(of: columnNamesUsedInQuery[columnNameArrayIndex])!
                                if indexOfColumnInDeconstructedSentenceArray < indexOfFirstTableOccurrence {
                                    columnsAppearingBeforeFirstTable.append(deconstructedSentence[indexOfColumnInDeconstructedSentenceArray])
                                } else {
                                    columnsAppearBeforeFirstTable = false
                                }
                            } else {
                                columnsAppearBeforeFirstTable = false
                            }
                        }
                        //TODO: take care of prunedDeconstructedSentence before concatenation
                        // there could still be additional conditions/where clauses after the initial select + from clauses
                        // e.g. we've sorted up to SELECT X, Y, Z, FROM TABLENAME | (we haven't processed this part) -> (WHERE X = ARBITRARY AND Y = RANDOM)
                        prunedDeconstructedSentence = columnsAppearingBeforeFirstTable + prunedDeconstructedSentence
                        print("After columns: " + String(describing: prunedDeconstructedSentence))
                        let columnNamesAppearingBeforeFirstTable = columnsAppearingBeforeFirstTable.map({ $0.0 })
                        let tableString = prunedDeconstructedSentence[columnNameArrayIndex+1].0
                        let sqlString = "SELECT " + columnNamesAppearingBeforeFirstTable.joined(separator: ", ") + " FROM " + tableString
                        self.sqlTextView.text = "\"" + sentence + "\"" + "\n\n=\n\n" + sqlString
                        self.verbalTextView.text = DatabaseHelper.executeSql(sql: sqlString, columns: columnNamesAppearingBeforeFirstTable, table: tableString).joined(separator: ".\n")
                        
                        print(sqlString)
                    } else if indexOfFirstColumnOccurrence > indexOfFirstTableOccurrence {
                        // likely format: select x,y,z from tableName where x has a value of abc and def is y and z = 100
                        
                        var columnsAppearingAfterFirstTable = [deconstructedSentence[indexOfFirstColumnOccurrence]]
                        
                        var columnsAppearAfterFirstTable = true
                        
                        var indexOfColumnInDeconstructedSentenceArray = indexOfFirstColumnOccurrence
                        var columnNameArrayIndex = 0
                        while columnsAppearAfterFirstTable {
                            if columnNameArrayIndex < (columnNamesUsedInQuery.count - 1) {
                                columnNameArrayIndex += 1
                                // when .suffix() is used, indices don't get reset to zero, they start relative to the suffix where they where cut off
                                // e.g. if you do suffix at 2, the first index is 2
                                indexOfColumnInDeconstructedSentenceArray = deconstructedWords.index(of: columnNamesUsedInQuery[columnNameArrayIndex])!
                                columnsAppearingAfterFirstTable.append(deconstructedSentence[indexOfColumnInDeconstructedSentenceArray])
                            } else {
                                columnsAppearAfterFirstTable = false
                            }
                        }
                        
                        
                        //TODO: take care of prunedDeconstructedSentence before concatenation
                        // there could still be additional conditions/where clauses after the initial select + from clauses
                        // e.g. we've sorted up to SELECT X, Y, Z, FROM TABLENAME | (we haven't processed this part) -> (WHERE X = ARBITRARY AND Y = RANDOM)
                        prunedDeconstructedSentence = columnsAppearingAfterFirstTable + prunedDeconstructedSentence
                        print("After columns: " + String(describing: prunedDeconstructedSentence))
                        var columnsNamesAppearingAfterFirstTable = columnsAppearingAfterFirstTable.map({ $0.0 })
                        let tableString = prunedDeconstructedSentence[columnNameArrayIndex+1].0
                        var columnAndConditionWithConditionType = [String:(String,String)]()
                        
                        var actuallyOrderedColumnArray = [String]()
                        for i in 0...deconstructedWords.count - 1 {
                            if columnsNamesAppearingAfterFirstTable.contains(deconstructedWords[i]) {
                                actuallyOrderedColumnArray.append(deconstructedWords[i])
                            }
                        }
                        columnsNamesAppearingAfterFirstTable = actuallyOrderedColumnArray
                        
                        
                        var i = 1
                        for column in columnsNamesAppearingAfterFirstTable {
                            var notFoundConditionOrExhausted = true
                            while notFoundConditionOrExhausted {
                                let indexOfColumn = deconstructedWords.index(of: column)!
                                var startingSearchIndex = indexOfColumn
                                if startingSearchIndex-i >= indexOfFirstTableOccurrence {
                                    startingSearchIndex -= i
                                    let partOfSpeech = deconstructedSentence[startingSearchIndex].1
                                    if partOfSpeech == NSLinguisticTag.number.rawValue || partOfSpeech == NSLinguisticTag.placeName.rawValue || partOfSpeech == NSLinguisticTag.personalName.rawValue || partOfSpeech == NSLinguisticTag.organizationName.rawValue {
                                        columnAndConditionWithConditionType[column] = (deconstructedWords[startingSearchIndex], partOfSpeech == NSLinguisticTag.number.rawValue ? NSLinguisticTag.number.rawValue : "Name")
                                        deconstructedWords.remove(at: startingSearchIndex)
                                        deconstructedSentence.remove(at: startingSearchIndex)
                                        notFoundConditionOrExhausted = false
                                        continue
                                    }
                                } else {
                                    if indexOfColumn+i > deconstructedSentence.count - 1 {
                                        notFoundConditionOrExhausted = false
                                    }
                                }
                                startingSearchIndex = indexOfColumn
                                 if startingSearchIndex+i <= deconstructedSentence.count - 1 {
                                     startingSearchIndex += i
                                     let partOfSpeech = deconstructedSentence[startingSearchIndex].1
                                    if partOfSpeech == NSLinguisticTag.number.rawValue || partOfSpeech == NSLinguisticTag.placeName.rawValue || partOfSpeech == NSLinguisticTag.personalName.rawValue || partOfSpeech == NSLinguisticTag.organizationName.rawValue {
                                        columnAndConditionWithConditionType[column] = (deconstructedWords[startingSearchIndex], partOfSpeech == NSLinguisticTag.number.rawValue ? NSLinguisticTag.number.rawValue : "Name")
                                        deconstructedWords.remove(at: startingSearchIndex)
                                        deconstructedSentence.remove(at: startingSearchIndex)
                                        notFoundConditionOrExhausted = false
                                        continue
                                     }
                                 } else {
                                    if indexOfColumn-i < indexOfFirstTableOccurrence {
                                        notFoundConditionOrExhausted = false
                                    }
                                }
                                i += 1
                            }
                        }
                        var sql = ""
                        self.verbalTextView.text = DatabaseHelper.executeSelectAllWhereSql(sqlString: &sql, table: tableString, whereColumns: Array(columnAndConditionWithConditionType.keys), whereValuesAndTypes: Array(columnAndConditionWithConditionType.values)).joined(separator: ".\n\n")
                        self.sqlTextView.text = "\"" + sentence + "\"" + "\n\n=\n\n" + sql
//                        print(sqlString)
                        
                    } else {
                        self.verbalTextView.text = "I'm not sure I understand. I can't determine your intent, perhaps try rephrasing or simplifying your query."
                    }
                    // Cannot determine intent, please try rephrasing or simplifying your query
                    print(tablesAndColumnsUsedInQuery)
                    
                    // TODO: do levenshtein distance on 2-part column names/table names so invoice_item is matched too etc
                    // TODO: intelligently determine delimiter e.g. camelcased attribute, character, etc
                    
                    self.audioEngine.stop()
                    inputNode.removeTap(onBus: 0)
                    
                    self.recognitionRequest = nil
                    self.recognitionTask = nil
                    
                    self.microphoneButton.isEnabled = true
                    self.microphoneButton.setTitle("Start Recording", for: .normal)
                    
                    
                    self.speak(text: self.verbalTextView.text)
                }
                
            }
            
        })
        
        
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { (buffer, when) in
            self.recognitionRequest?.append(buffer)
        }
        
        // Prepare the audio engine to allocate resources
        audioEngine.prepare()
        
        do {
            // Start the audio engine
            try audioEngine.start()
        } catch {
            print("audioEngine couldn't start because of an error.")
        }
        
        verbalTextView.text = "(go ahead, i'm listening)"
        sqlTextView.text = ""
    }
    
    func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        microphoneButton.isEnabled = available
    }
    
    func speechRecognitionDidDetectSpeech(_ task: SFSpeechRecognitionTask) {
        //
    }
    
    func speechRecognitionTaskWasCancelled(_ task: SFSpeechRecognitionTask) {
        //
    }
    
    func speechRecognitionTaskFinishedReadingAudio(_ task: SFSpeechRecognitionTask) {
        //
    }
    
    func speechRecognitionTask(_ task: SFSpeechRecognitionTask, didFinishSuccessfully successfully: Bool) {
        //
    }
    
    func speechRecognitionTask(_ task: SFSpeechRecognitionTask, didHypothesizeTranscription transcription: SFTranscription) {
        //
    }
    
    func speechRecognitionTask(_ task: SFSpeechRecognitionTask, didFinishRecognition recognitionResult: SFSpeechRecognitionResult) {
        //
    }
    
    func speak(text: String) {
        let speechUtterance = AVSpeechUtterance(string: text)
        speechUtterance.rate = AVSpeechUtteranceDefaultSpeechRate
        speechUtterance.pitchMultiplier = 1
        speechUtterance.volume = 100
        speechUtterance.postUtteranceDelay = 0.005
        
        let voice = AVSpeechSynthesisVoice(language: "en-US")
        speechUtterance.voice = voice
        
        speechSynthesizer.speak(speechUtterance)
    }

}
