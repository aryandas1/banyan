// PersonSheetViewModelTests.swift
// The person-sheet VM's marriage derivations: pairing partners with their unions and
// exposing each union's type for the Family-row label.

import Foundation
import Testing
@testable import Banyan

@MainActor
@Suite("PersonSheetViewModel")
struct PersonSheetViewModelTests {

    @Test func marriagesPairEachPartnerWithTheirUnion() throws {
        // Given a focal person with a married partner (dated) and an unmarried partner
        let builder = try TestTreeBuilder()
        let treeId = UUID()
        let focal = builder.makePerson(firstName: "Aryan", treeId: treeId)
        let spouse = builder.makePerson(firstName: "Meera", treeId: treeId)
        let partner = builder.makePerson(firstName: "Advika", treeId: treeId)
        let married = builder.makeUnion(type: .married, treeId: treeId)
        married.startDate = PartialDate(year: 1995, month: 5, day: 20)
        builder.link(person: focal, to: married, role: .partner)
        builder.link(person: spouse, to: married, role: .partner)
        let partnered = builder.makeUnion(type: .partnered, treeId: treeId)
        builder.link(person: focal, to: partnered, role: .partner)
        builder.link(person: partner, to: partnered, role: .partner)

        // When the sheet VM loads
        let vm = PersonSheetViewModel(person: focal, graphService: GraphService())

        // Then both partnerships surface, each paired to its own union
        #expect(vm.marriages.count == 2)
        let meeraMarriage = vm.marriages.first { $0.partner.id == spouse.id }
        #expect(meeraMarriage?.union.type == .married)
        #expect(meeraMarriage?.startDate?.year == 1995)
        #expect(vm.marriages.first { $0.partner.id == partner.id }?.union.type == .partnered)
    }

    @Test func partnerUnionTypeReflectsTheSharedUnion() throws {
        // Given a focal person with one married and one unmarried partner
        let builder = try TestTreeBuilder()
        let treeId = UUID()
        let focal = builder.makePerson(firstName: "Aryan", treeId: treeId)
        let spouse = builder.makePerson(firstName: "Meera", treeId: treeId)
        let partner = builder.makePerson(firstName: "Advika", treeId: treeId)
        let married = builder.makeUnion(type: .married, treeId: treeId)
        builder.link(person: focal, to: married, role: .partner)
        builder.link(person: spouse, to: married, role: .partner)
        let partnered = builder.makeUnion(type: .partnered, treeId: treeId)
        builder.link(person: focal, to: partnered, role: .partner)
        builder.link(person: partner, to: partnered, role: .partner)
        let vm = PersonSheetViewModel(person: focal, graphService: GraphService())

        // Then each partner's union type drives the label choice
        #expect(vm.partnerUnionType(with: spouse) == .married)
        #expect(vm.partnerUnionType(with: partner) == .partnered)
    }
}
