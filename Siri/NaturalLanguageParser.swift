//
//  NaturalLanguageParser.swift
//  Siri
//
//  Created by Josue Espinosa on 9/21/17.
//  Copyright © 2017 Josue Espinosa. All rights reserved.
//

import Foundation

class NaturalLanguageParser {
    static let taggerOptions: NSLinguisticTagger.Options = [.joinNames, .omitWhitespace, .omitPunctuation]
    static var linguisticTagger: NSLinguisticTagger = {
        let tagSchemes = NSLinguisticTagger.availableTagSchemes(forLanguage: "en")
        return NSLinguisticTagger(tagSchemes: tagSchemes, options: Int(taggerOptions.rawValue))
    }()
    
    static func language(text: String) -> String? {
        let tagger = NSLinguisticTagger(tagSchemes: [.language], options: 0)
        tagger.string = text
        return tagger.dominantLanguage
    }
    
    static func partsOfSpeech(text: String) -> [(String, String)] {
        print(text)
        linguisticTagger.string = text
        linguisticTagger.enumerateTags(in: NSMakeRange(0, linguisticTagger.string!.count), scheme: NSLinguisticTagScheme.nameTypeOrLexicalClass, options: self.taggerOptions) { (tag, tokenRange, _, _) in
            let token = (linguisticTagger.string! as NSString).substring(with: tokenRange)
            print("\(token) -> \(tag?.rawValue ?? "")")
        }
        
        let options: NSLinguisticTagger.Options = [.omitWhitespace, .omitPunctuation, .joinNames]
        let schemes = NSLinguisticTagger.availableTagSchemes(forLanguage: "en")
        let tagger = NSLinguisticTagger(tagSchemes: schemes, options: Int(options.rawValue))
        tagger.string = text
        var arr = [(String, String)]()
        tagger.enumerateTags(in: NSMakeRange(0, text.count), scheme: NSLinguisticTagScheme.nameTypeOrLexicalClass, options: options) { (tag, tokenRange, _, _) in
            let token = (text as NSString).substring(with: tokenRange)
            print(token)
            arr.append((token, tag?.rawValue ?? ""))
        }
        return arr
    }
    
    static func lemmatize(text: String) -> String {
        let tagger = NSLinguisticTagger(tagSchemes:[.lemma], options: 0)
        
        tagger.string = text
        let range = NSRange(location:0, length: text.count)
        let options: NSLinguisticTagger.Options = [.omitPunctuation, .omitWhitespace]
        
        var lemmatizedSentence = ""
        
        tagger.enumerateTags(in: range, unit: .word, scheme: .lemma, options: options) { tag, tokenRange, stop in
            
            if let lemma = tag?.rawValue {
                lemmatizedSentence += (lemmatizedSentence.count == 0) ? lemma : " " + lemma
                // display changed values in red
                // e.g. parenthesis values in red
                // dog(s) -> dog
            }
        }
        return lemmatizedSentence
    }
}
