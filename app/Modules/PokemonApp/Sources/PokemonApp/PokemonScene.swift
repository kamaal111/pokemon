//
//  PokemonScene.swift
//  PokemonApp
//
//  Created by Kamaal M Farah on 5/16/26.
//

import PokemonOcr
import SwiftUI

public struct PokemonScene: Scene {
    public init() {}

    public var body: some Scene {
        WindowGroup {
            PokemonOcrScreen()
        }
    }
}
