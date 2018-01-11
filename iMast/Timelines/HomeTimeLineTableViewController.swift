//
//  HomeTimeLineTableViewController.swift
//  iMast
//
//  Created by rinsuki on 2017/05/24.
//  Copyright © 2017年 rinsuki. All rights reserved.
//

import UIKit
import SwiftyJSON
import Hydra

class HomeTimeLineTableViewController: TimeLineTableViewController {
    
    override func loadTimeline() -> Promise<Void>{
        return Promise<Void>() { resolve, reject, _ in
            MastodonUserToken.getLatestUsed()?.get("timelines/home").then { (res: JSON) in
                if (res.array != nil) {
                    self._addNewPosts(posts: res.arrayValue)
                    // self.posts = res.arrayValue
                }
                resolve(Void())
            }
        }
    }
    override func refreshTimeline() {
        MastodonUserToken.getLatestUsed()?.get("timelines/home?limit=40&since_id="+(self.posts.count >= 1 ? self.posts[0].id.string : "")).then { (res: JSON) in
            if (res.array != nil) {
                self.addNewPosts(posts: res.arrayValue)
                self.refreshControl?.endRefreshing()
            }
        }
    }
    
    override func readMoreTimeline() {
        MastodonUserToken.getLatestUsed()?.get("timelines/home?limit=40&max_id="+self.posts[self.posts.count-1].id.string).then { (res: JSON) in
            if (res.array != nil) {
                print(res.array)
                self.appendNewPosts(posts: res.arrayValue.map {print($0);return try! MastodonPost.decode(json: $0)})
                self.isReadmoreLoading = false
            }
        }
    }
    
    override func websocketEndpoint() -> String? {
        return "user"
    }
}
