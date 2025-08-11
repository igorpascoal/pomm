//
//  PersistenceService.swift
//  Pomm
//
//  Created by Igor Pascoal on 10/08/2025.
//

import CoreData

enum PersistenceService {
    static func saveSession(
        startDate: Date,
        durationMinutes: Int,
        completed: Bool,
        colorHue: Double,
        context: NSManagedObjectContext
    ) {
        let obj = NSEntityDescription.insertNewObject(forEntityName: "Session", into: context)
        obj.setValue(UUID(), forKey: "id")
        obj.setValue(startDate, forKey: "startDate")
        obj.setValue(Int16(durationMinutes), forKey: "durationMinutes")
        obj.setValue(completed, forKey: "completed")
        obj.setValue(colorHue, forKey: "colorHue")
        do {
            try context.save()
        } catch {
            // Keep it simple: for MVP just print; you can add better error UI later
            print("Failed to save Session: \(error)")
            context.rollback()
        }
    }
}
