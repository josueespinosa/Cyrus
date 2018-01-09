//
//  NaturalLanguageParser.swift
//  Cyrus
//
//  Created by Josue Espinosa on 12/23/17.
//  Copyright © 2017 Josue Espinosa. All rights reserved.
//

import Foundation

class NaturalLanguageParser {

    static let options: NSLinguisticTagger.Options = [.joinNames, .omitPunctuation, .omitWhitespace]
    static var linguisticTagger: NSLinguisticTagger = {
        let schemes = NSLinguisticTagger.availableTagSchemes(forLanguage: "en")
        return NSLinguisticTagger(tagSchemes: schemes, options: Int(options.rawValue))
    }()

    static func lemmatize(text: String) -> String {
        linguisticTagger.string = text
        let range = NSRange(location: 0, length: text.count)
        let options: NSLinguisticTagger.Options = [.omitPunctuation, .omitWhitespace]

        var lemmatizedSentence = ""

        linguisticTagger.enumerateTags(in: range, unit: .word, scheme: .lemma, options: options) { (tag, _, _) in
            if let lemma = tag?.rawValue {
                lemmatizedSentence += (lemmatizedSentence.count == 0) ? lemma : " " + lemma
            }
        }
        return lemmatizedSentence
    }

    static func partsOfSpeech(text: String) -> [(String, String)] {
        linguisticTagger.string = text
        let range = NSRange(location: 0, length: text.count)
        let options: NSLinguisticTagger.Options = [.joinNames, .omitPunctuation, .omitWhitespace]

        var partsOfSpeech = [(String, String)]()

        linguisticTagger.enumerateTags(in: range,
                             scheme: .nameTypeOrLexicalClass,
                             options: options) { (tag, tokenRange, _, _) in
            let token = (text as NSString).substring(with: tokenRange)
            print("\(token) -> \(tag?.rawValue ?? "")")
            partsOfSpeech.append((token, tag?.rawValue ?? ""))
        }
        return partsOfSpeech
    }

}
