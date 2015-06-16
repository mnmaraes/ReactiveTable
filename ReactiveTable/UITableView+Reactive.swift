//
//  UITableView+Reactive.swift
//  ReactiveAdventures
//
//  Created by Murillo Nicacio de Maraes on 6/15/15.
//  Copyright (c) 2015 TIL. All rights reserved.
//

import UIKit
import ReactiveCocoa

//MARK: Helper Structs
public struct Overview<T> {
    let store: [[T]]

    public init(store: [[T]]) {
        self.store = store
    }

    var sectionCount: Int { return store.count }

    var first: [T] { return store[0] }

    subscript(section: Int) -> [T] { return store[section] }

    subscript(section: Int, row: Int) -> T { return store[section][row] }

    subscript(path: NSIndexPath) -> T { return self[path.section, path.row] }
}

//MARK: Protocols
public protocol IndexedDataSource {
    typealias ItemType

    var overview: MutableProperty<Overview<ItemType>> { get set }
}

public protocol ReactiveLayoutDataSource: IndexedDataSource {
    typealias CellType: UITableViewCell

    func identifierForItem(item: ItemType) -> String
    func heightForItem(item: ItemType) -> CGFloat
    func cellForItem(preConfiguredCell: CellType?, item: ItemType) -> CellType
}

public protocol ReactiveSectionDataSource: IndexedDataSource {
    static func arrange(items: [ItemType]) -> [[ItemType]]

    func headerViewForSection(items: [ItemType]) -> UIView?
    func footerViewForSection(items: [ItemType]) -> UIView?

    func headerTitleForSection(items: [ItemType]) -> String?
    func footerTitleForSection(items: [ItemType]) -> String?
}

public protocol ReactiveActionDelegate {
    var willDisplayCellSignal: Signal<(UITableViewCell, NSIndexPath), NoError> { get }
    var didSelectSignal: Signal<NSIndexPath, NoError> { get }
}

//MARK: Structs
public struct LayoutDataSource<DataSourceType: ReactiveLayoutDataSource>: UITableViewLayoutDelegate {
    private let reactiveDataSource: DataSourceType

    public init(reactiveDataSource: DataSourceType) {
        self.reactiveDataSource = reactiveDataSource
    }

    func numberOfRows(tableView: UITableView) -> Int {
        return reactiveDataSource.overview.value.first.count
    }

    func heightForIndexPath(indexPath: NSIndexPath, inTableView tableView: UITableView) -> CGFloat {
        return reactiveDataSource.heightForItem(reactiveDataSource.overview.value[indexPath])
    }

    func cellForIndexPath(indexPath: NSIndexPath, inTableView tableView: UITableView) -> UITableViewCell {
        let item = reactiveDataSource.overview.value[indexPath]
        let identifier = reactiveDataSource.identifierForItem(item)

        let cell = tableView.dequeueReusableCellWithIdentifier(identifier, forIndexPath: indexPath) as? DataSourceType.CellType

        return reactiveDataSource.cellForItem(cell, item: item)
    }
}

public struct SectionDataSource<DataSourceType: ReactiveSectionDataSource>: UITableViewSectionDelegate {
    private let reactiveDataSource: DataSourceType

    public init(reactiveDataSource: DataSourceType) {
        self.reactiveDataSource = reactiveDataSource
    }

    func numberOfSections(tableView: UITableView) -> Int {
        return reactiveDataSource.overview.value.sectionCount
    }

    func numberOfRows(tableView: UITableView, inSection section: Int) -> Int {
        return reactiveDataSource.overview.value[section].count
    }

    func headerView(section: Int, inTableView tableView: UITableView) -> UIView? {
        let items = reactiveDataSource.overview.value[section]
        return reactiveDataSource.headerViewForSection(items)
    }

    func footerView(section: Int, inTableView tableView: UITableView) -> UIView? {
        let items = reactiveDataSource.overview.value[section]
        return reactiveDataSource.footerViewForSection(items)
    }

    func headerTitle(section: Int, inTableView tableView: UITableView) -> String? {
        let items = reactiveDataSource.overview.value[section]
        return reactiveDataSource.headerTitleForSection(items)
    }

    func footerTitle(section: Int, inTableView tableView: UITableView) -> String? {
        let items = reactiveDataSource.overview.value[section]
        return reactiveDataSource.footerTitleForSection(items)
    }
}

//MARK: Reactive Structs
struct ActionDelegate: UITableViewActionDelegate, ReactiveActionDelegate {
    private let willDisplayCellAction: Action<(UITableViewCell, NSIndexPath), (UITableViewCell, NSIndexPath), NoError>
    private let didSelectAction: Action<NSIndexPath, NSIndexPath, NoError>

    init() {
        willDisplayCellAction = Action { SignalProducer(value: $0) }
        didSelectAction = Action { SignalProducer(value: $0) }
    }

    var willDisplayCellSignal: Signal<(UITableViewCell, NSIndexPath), NoError> { return willDisplayCellAction.values }
    var didSelectSignal: Signal<NSIndexPath, NoError> { return didSelectAction.values }

    func willDisplayCell(cell: UITableViewCell, inTableView tableView: UITableView, atIndexPath indexPath: NSIndexPath) {
        willDisplayCellAction.apply(cell, indexPath) |> start()
    }

    func didSelect(tableView: UITableView, atIndexPath indexPath: NSIndexPath) {
        didSelectAction.apply(indexPath) |> start()
    }
}

public extension UITableView {

    public func updateWithSignal<Layout: ReactiveLayoutDataSource,
        Section: ReactiveSectionDataSource,
        T where
        T == Layout.ItemType,
        T == Section.ItemType>(signal: Signal<[T], NoError>, layoutDataSource: Layout, sectionDataSource: Section? = nil) -> Disposable {

            var layout = layoutDataSource
            var section = sectionDataSource

            let overview = MutableProperty<Overview<T>>(Overview(store: [[]]))

            let sectionSource: SectionDataSource<Section>?
            let updateSignal: Signal<Overview<T>, NoError>

            if let section = sectionDataSource {
                var s = section
                updateSignal = signal |> map { Overview(store: Section.arrange($0)) }

                s.overview = overview

                sectionSource = SectionDataSource(reactiveDataSource: s)
            } else {
                updateSignal = signal |> map { Overview(store: [$0]) }

                sectionSource = nil
            }

            let firstDisposable = overview <~ updateSignal

            layout.overview = overview

            let manager = DelegatedUITableViewManager(layoutDelegate: LayoutDataSource(reactiveDataSource: layout),
                        sectionDelegate: sectionSource,
                        actionDelegate: nil)

            let secondDisposable = overview.producer
                |> startOn(QueueScheduler.mainQueueScheduler)
                |> observeOn(QueueScheduler.mainQueueScheduler)
                |> on(started: { [unowned self] in
                    self.delegate = manager
                    self.dataSource = manager
                }, next: { [unowned self] next in
                    self.reloadData()
                }, disposed: {
                    self.delegate = nil
                    self.dataSource = nil
                    manager.holdOn = nil
                })
                |> start()

            return CompositeDisposable([firstDisposable, secondDisposable])
    }
}

