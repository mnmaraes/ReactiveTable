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

    public var sectionCount: Int { return store.count }

    var first: [T] { return store[0] }

    public subscript(section: Int) -> [T] { return store[section] }

    public subscript(section: Int, row: Int) -> T { return store[section][row] }

    public subscript(path: NSIndexPath) -> T { return self[path.section, path.row] }

    public func reduce<U>(initial: U, combine: (U, [T]) -> U) -> U {
        return self.store.reduce(initial, combine: combine)
    }

    public func isWithinBounds(path: NSIndexPath) -> Bool {
        if path.section < store.count && path.row < store[path.section].count {
            return true
        }

        return false
    }
}

func find<T: Equatable>(item: T, inOverview overview: Overview<T>) -> NSIndexPath? {
    return overview.store
        .reduce((nil, 0)) { (step, section) -> (NSIndexPath?, Int) in
            if step.1 == -1 {
                return step
            }else if let index = find(section, item) {
                return (NSIndexPath(forRow: index, inSection: step.1), -1)
            } else {
                return (step.0, step.1 + 1)
            }
        }.0
}

//MARK: Protocols
public protocol IndexedDataSource {
    typealias ItemType

    var overview: MutableProperty<Overview<ItemType>> { get set }
}

public protocol ReactiveLayoutDataSource: IndexedDataSource {
    typealias CellType: UITableViewCell

    func identifierForItem(item: ItemType) -> String
//    func heightForItem(item: ItemType) -> CGFloat
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
    var didEndDisplayingCellSignal: Signal<(UITableViewCell, NSIndexPath), NoError> { get }
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

//    func heightForIndexPath(indexPath: NSIndexPath, inTableView tableView: UITableView) -> CGFloat {
//        return reactiveDataSource.heightForItem(reactiveDataSource.overview.value[indexPath])
//    }

    func cellForIndexPath(indexPath: NSIndexPath, inTableView tableView: UITableView) -> UITableViewCell {
        let nSections = reactiveDataSource.overview.value.sectionCount

        if nSections <= indexPath.section ||
            reactiveDataSource.overview.value[indexPath.section].count <= indexPath.row  {
                tableView.reloadData()
                return UITableViewCell()
        }

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
    private let didEndDisplayingCellAction: Action<(UITableViewCell, NSIndexPath), (UITableViewCell, NSIndexPath), NoError>
    private let didSelectAction: Action<NSIndexPath, NSIndexPath, NoError>

    init() {
        willDisplayCellAction = Action { SignalProducer(value: $0) }
        didEndDisplayingCellAction = Action { SignalProducer(value: $0) }
        didSelectAction = Action { SignalProducer(value: $0) }
    }

    var willDisplayCellSignal: Signal<(UITableViewCell, NSIndexPath), NoError> { return willDisplayCellAction.values }
    var didEndDisplayingCellSignal: Signal<(UITableViewCell, NSIndexPath), NoError> { return didEndDisplayingCellAction.values }
    var didSelectSignal: Signal<NSIndexPath, NoError> { return didSelectAction.values }

    func willDisplayCell(cell: UITableViewCell, inTableView tableView: UITableView, atIndexPath indexPath: NSIndexPath) {
        willDisplayCellAction.apply(cell, indexPath) |> start()
    }

    func didEndDisplayingCell(cell: UITableViewCell, inTableView tableView: UITableView, atIndexPath indexPath: NSIndexPath) {
        didEndDisplayingCellAction.apply(cell, indexPath) |> start()
    }

    func didSelect(tableView: UITableView, atIndexPath indexPath: NSIndexPath) {
        didSelectAction.apply(indexPath) |> start()
    }
}

public struct SignalDelegate<T> {
    public let willDisplaySignal: Signal<(UITableViewCell, T), NoError>
    public let didEndDisplayingSignal: Signal<(UITableViewCell, T), NoError>
    public let didSelectSignal: Signal<T, NoError>
}

public extension UITableView {

    public func updateWithSignal<Layout: ReactiveLayoutDataSource,
        Section: ReactiveSectionDataSource,
        T where
        T == Layout.ItemType,
        T == Section.ItemType>(signal: Signal<[T], NoError>,
        layoutDataSource: Layout,
        sectionDataSource: Section,
        updateBlock: ((UITableView, Overview<T>, Overview<T>) -> Void)? = nil) -> SignalDelegate<T> {

            var layout = layoutDataSource
            var section = sectionDataSource

            let overview = MutableProperty<Overview<T>>(Overview(store: [[]]))

            let sectionSource: SectionDataSource<Section>?
            let updateSignal: Signal<Overview<T>, NoError>

                var s = sectionDataSource
                updateSignal = signal |> map { Overview(store: Section.arrange($0)) }

                sectionSource = SectionDataSource(reactiveDataSource: s)

            let firstDisposable = overview <~ updateSignal

            let delegate = ActionDelegate()

            let manager = DelegatedUITableViewManager(layoutDelegate: LayoutDataSource(reactiveDataSource: layout),
                sectionDelegate: sectionSource,
                actionDelegate: delegate)

            manager.hold = overview

            let defaultBlock:(UITableView, Overview<T>, Overview<T>) -> Void

            if let update = updateBlock {
                defaultBlock = update
            } else {
                defaultBlock = {table, _, _ in table.reloadData() }
            }

            let secondDisposable = overview.producer
                |> startOn(QueueScheduler.mainQueueScheduler)
                |> observeOn(QueueScheduler.mainQueueScheduler)
                |> on(started: { [weak self] in
                    self?.delegate = manager
                    self?.dataSource = manager
                }, disposed: { [weak self] in
                    self?.delegate = nil
                    self?.dataSource = nil
                    manager.holdOn = nil
                })
                |> combinePrevious(Overview(store: [[]]))
                |> start(next: { [weak self] previous, next in
                    s.overview.put(next)
                    layout.overview.put(next)

                    if let weakSelf = self {
                        defaultBlock(weakSelf, previous, next)
                    }
                })

            let willDisplay = delegate.willDisplayCellSignal
                |> map { ($0, s.overview.value[$1]) }

            let didDisplay = delegate.didEndDisplayingCellSignal
                |> map { ($0, s.overview.value[$1]) }

            let didSelect = delegate.didSelectSignal
                |> map { s.overview.value[$0] }

            let sDelegate = SignalDelegate(willDisplaySignal: willDisplay,
                didEndDisplayingSignal: didDisplay,
                didSelectSignal: didSelect)

            let disposable = CompositeDisposable([firstDisposable, secondDisposable])

            self.rac_willDeallocSignal().toSignalProducer()
                |> start(next: {_ in disposable.dispose() })

            return sDelegate
    }


    public func updateWithSignal<Layout: ReactiveLayoutDataSource,
        T where
        T == Layout.ItemType>(signal: Signal<[T], NoError>,
        layoutDataSource: Layout,
        updateBlock: ((UITableView, Overview<T>, Overview<T>) -> Void)? = nil) -> SignalDelegate<T> {

            var layout = layoutDataSource

            let overview = MutableProperty<Overview<T>>(Overview(store: [[]]))

            let updateSignal: Signal<Overview<T>, NoError>

            updateSignal = signal |> map { Overview(store: [$0]) }

            let firstDisposable = overview <~ updateSignal

            let delegate = ActionDelegate()

            let manager = DelegatedUITableViewManager(layoutDelegate: LayoutDataSource(reactiveDataSource: layout), actionDelegate: delegate)

            manager.hold = overview

            let defaultBlock:(UITableView, Overview<T>, Overview<T>) -> Void

            if let update = updateBlock {
                defaultBlock = update
            } else {
                defaultBlock = {table, _, _ in table.reloadData() }
            }

            let secondDisposable = overview.producer
                |> startOn(QueueScheduler.mainQueueScheduler)
                |> observeOn(QueueScheduler.mainQueueScheduler)
                |> on(started: { [weak self] in
                    self?.delegate = manager
                    self?.dataSource = manager
                    }, disposed: { [weak self] in
                        self?.delegate = nil
                        self?.dataSource = nil
                        manager.holdOn = nil
                    })
                |> combinePrevious(Overview(store: [[]]))
                |> start(next: { [weak self] previous, next in
                    layout.overview.put(next)

                    if let weakSelf = self {
                        defaultBlock(weakSelf, previous, next)
                    }
                })


            let willDisplay = delegate.willDisplayCellSignal
                |> map {cell, path in
                    return layout.overview.value.isWithinBounds(path) ? (cell, layout.overview.value[path]) : nil
                }
                |> ignoreNil

            let didDisplay = delegate.didEndDisplayingCellSignal
                |> map {cell, path in
                    return layout.overview.value.isWithinBounds(path) ? (cell, layout.overview.value[path]) : nil
                }
                |> ignoreNil

            let didSelect = delegate.didSelectSignal
                |> map { layout.overview.value[$0] }

            let sDelegate = SignalDelegate(willDisplaySignal: willDisplay,
                didEndDisplayingSignal: didDisplay,
                didSelectSignal: didSelect)

            let disposable = CompositeDisposable([firstDisposable, secondDisposable])

            self.rac_willDeallocSignal().toSignalProducer()
                |> start(next: {_ in disposable.dispose() })

            return sDelegate
    }
}

