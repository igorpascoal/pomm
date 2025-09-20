//
//  TimerState.swift
//  Pomm
//
//  Created by Igor Pascoal on 10/08/2025.
//
import Foundation

enum AppState {
    case idle
    case countingDown
    case running
    case breakRunning
    case ended // not used in current flow but kept for completeness
}
