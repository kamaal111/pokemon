//
//  Character+PokemonScripts.swift
//  PokemonCardPipeline
//
//  Created by Kamaal M Farah on 5/30/26.
//

import Foundation

extension Character {
    public var isLatinScript: Bool {
        unicodeScalars.contains(where: \.isLatinScript)
    }

    public var isHangulScript: Bool {
        unicodeScalars.contains(where: \.isHangulScript)
    }

    public var isKanaScript: Bool {
        unicodeScalars.contains(where: \.isKanaScript)
    }

    public var isKanjiOrChineseScript: Bool {
        unicodeScalars.contains(where: \.isKanjiOrChineseScript)
    }
}

extension Unicode.Scalar {
    public var isLatinScript: Bool {
        (0x0041...0x005A).contains(value)
            || (0x0061...0x007A).contains(value)
    }

    public var isHangulScript: Bool {
        (0xAC00...0xD7AF).contains(value)
            || (0x1100...0x11FF).contains(value)
            || (0x3130...0x318F).contains(value)
    }

    public var isHiraganaScript: Bool {
        (0x3040...0x309F).contains(value)
    }

    public var isKatakanaScript: Bool {
        (0x30A0...0x30FF).contains(value)
    }

    public var isKanaScript: Bool {
        isHiraganaScript || isKatakanaScript
    }

    public var isKanjiOrChineseScript: Bool {
        (0x4E00...0x9FFF).contains(value)
    }
}
