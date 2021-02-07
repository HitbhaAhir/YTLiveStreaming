//
//  StreamListDataSource.swift
//  YouTubeLiveVideo
//
//  Created by Sergey Krotkih
//

import Foundation
import YTLiveStreaming
import RxDataSources
import RxSwift

struct SectionModel {
    var model: String
    var items: [LiveBroadcastStreamModel]
    var error: String? = nil
}

extension SectionModel: SectionModelType {
    init(original: SectionModel, items: [LiveBroadcastStreamModel]) {
        self = original
        self.items = items
    }
}

extension YTLiveVideoState {
    var index: Int {
        switch self {
        case .upcoming:
            return 0
        case .active:
            return 1
        case .completed:
            return 2
        case .all:
            return 3
        }
    }
    func description() -> String {
        switch self {
        case .upcoming:
            return "Upcoming"
        case .active:
            return "Live now"
        case .completed:
            return "Completed"
        case .all:
            return "-"
        }
    }
}

class StreamListDataSource: NSObject, BroadcastsDataFetcher {
    
    var broadcastsAPI: BroadcastsAPI!
    
    let dispatchGroup = DispatchGroup()
    
    var rxData: PublishSubject<[SectionModel]> = PublishSubject<[SectionModel]>()
    
    private var data = [
        SectionModel(model: YTLiveVideoState.upcoming.description(), items: []),
        SectionModel(model: YTLiveVideoState.active.description(), items: []),
        SectionModel(model: YTLiveVideoState.completed.description(), items: [])
    ]
    
    func getUpcoming(for index: Int) -> LiveBroadcastStreamModel {
        assert(index < data[YTLiveVideoState.upcoming.index].items.count, "Broadcast index is invalid")
        return self.data[YTLiveVideoState.upcoming.index].items[index]
    }
    
    func getCurrent(for index: Int) -> LiveBroadcastStreamModel {
        assert(index < data[YTLiveVideoState.active.index].items.count, "Broadcast index is invalid")
        return self.data[YTLiveVideoState.active.index].items[index]
    }
    
    func getPast(for index: Int) -> LiveBroadcastStreamModel {
        assert(index < data[YTLiveVideoState.completed.index].items.count, "Broadcast index is invalid")
        return self.data[YTLiveVideoState.completed.index].items[index]
    }
    
    func loadData() {
        for i in 0..<data.count {
            data[i].items.removeAll()
        }
        rxData.onNext(self.data)
        dispatchGroup.enter()
        self.broadcastsAPI.getAllBroadcasts { (_, _, _) in
            self.dispatchGroup.leave()
        }
        dispatchGroup.enter()
        self.broadcastsAPI.getUpcomingBroadcasts { result in
            switch result {
            case .success(let streams):
                self.data[YTLiveVideoState.upcoming.index].items += streams
            case .failure(let error):
                self.data[YTLiveVideoState.upcoming.index].error =  YTLiveVideoState.upcoming.description() + ":\n" + error.message()
            }
            self.dispatchGroup.leave()
        }
        dispatchGroup.enter()
        self.broadcastsAPI.getLiveNowBroadcasts { result in
            switch result {
            case .success(let streams):
                self.data[YTLiveVideoState.active.index].items += streams
            case .failure(let error):
                self.data[YTLiveVideoState.active.index].error = YTLiveVideoState.active.description() + ":\n" + error.message()
            }
            self.dispatchGroup.leave()
        }
        dispatchGroup.enter()
        self.broadcastsAPI.getCompletedBroadcasts { result in
            switch result {
            case .success(let streams):
                self.data[YTLiveVideoState.completed.index].items += streams
            case .failure(let error):
                self.data[YTLiveVideoState.completed.index].error =  YTLiveVideoState.completed.description() + ":\n" + error.message()
            }
            self.dispatchGroup.leave()
        }
        dispatchGroup.notify(queue: .main) {
            self.rxData.onNext(self.data)
        }
    }
}

