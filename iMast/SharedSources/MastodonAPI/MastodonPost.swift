//
//  MastodonPost.swift
//  iMast
//
//  Created by user on 2018/01/09.
//  Copyright © 2018年 rinsuki. All rights reserved.
//

import Foundation
import Hydra
import SwiftyJSON

class MastodonPost: Codable {
    let id: MastodonID
    let url: String?
    let account: MastodonAccount
    let inReplyToId: MastodonID?
    let inReplyToAccountId: MastodonID?
    let repost: MastodonPost?
    let status: String
    let createdAt: Date
    let repostCount: Int
    let favouritesCount: Int
    var reposted: Bool {
        return self._reposted ?? false
    }
    var _reposted: Bool?
    var favourited: Bool {
        return self._favourited ?? false
    }
    var _favourited: Bool?
    var muted: Bool {
        return self._muted ?? false
    }
    var _muted: Bool?
    let sensitive: Bool
    let spoilerText: String
    let attachments: [MastodonAttachment]
    let application: MastodonApplication?
    var pinned: Bool?
    private var _emojis: [MastodonCustomEmoji]?
    private var _profileEmojis: [MastodonCustomEmoji]?
    var emojis: [MastodonCustomEmoji] {
        return self._emojis ?? []
    }
    var profileEmojis: [MastodonCustomEmoji] {
        return self._profileEmojis ?? []
    }
    let visibility: String
    private(set) var mentions: [MastodonPostMention] = []

    enum CodingKeys: String, CodingKey {
        case id
        case url
        case account
        case inReplyToId = "in_reply_to_id"
        case inReplyToAccountId = "in_reply_to_account_id"
        case repost = "reblog"
        case status = "content"
        case createdAt = "created_at"
        case repostCount = "reblogs_count"
        case favouritesCount = "favourites_count"
        case _reposted = "reblogged"
        case _favourited = "favourited"
        case _muted = "muted"
        case sensitive
        case spoilerText = "spoiler_text"
        case pinned
        case application
        case attachments = "media_attachments"
        case _emojis = "emojis"
        case _profileEmojis = "profile_emojis"
        case visibility
        case mentions
    }
    
    @available(*, deprecated, message: "Do not use.")
    init() {
        fatalError("Swift 4.1 work around")
    }
}

class MastodonCustomEmoji: Codable {
    let shortcode: String
    let url: String
    enum CodingKeys: String, CodingKey {
        case shortcode
        case url
    }
    
    @available(*, deprecated, message: "Do not use.")
    init() {
        fatalError("Swift 4.1 work around")
    }
}

class MastodonPostContext: Codable {
    let ancestors: [MastodonPost]
    let descendants: [MastodonPost]
}

class MastodonPostMention: Codable {
    let url: String
    let username: String
    let acct: String
    let id: MastodonID
    
    @available(*, deprecated, message: "Do not use.")
    init() {
        fatalError("Swift 4.1 work around")
    }
}

extension MastodonUserToken {
    func newPost(status: String) -> Promise<MastodonPost> {
        return self.post("statuses", params: ["status": status]).then { res -> MastodonPost in
            return try MastodonPost.decode(json: res)
        }
    }

    func repost(post: MastodonPost) -> Promise<MastodonPost> {
        return self.post("statuses/\(post.id.string)/reblog", params: [:]).then { res -> MastodonPost in
            return try MastodonPost.decode(json: res)
        }
    }
    func unrepost(post: MastodonPost) -> Promise<MastodonPost> {
        return self.post("statuses/\(post.id.string)/unreblog", params: [:]).then { res -> MastodonPost in
            return try MastodonPost.decode(json: res)
        }
    }
    
    func favourite(post: MastodonPost) -> Promise<MastodonPost> {
        return self.post("statuses/\(post.id.string)/favourite", params: [:]).then { res -> MastodonPost in
            return try MastodonPost.decode(json: res)
        }
    }
    func unfavourite(post: MastodonPost) -> Promise<MastodonPost> {
        return self.post("statuses/\(post.id.string)/favourite", params: [:]).then { res -> MastodonPost in
            return try MastodonPost.decode(json: res)
        }
    }
    
    func delete(post: MastodonPost) -> Promise<Void> {
        return self.delete("statuses/\(post.id.string)").then { res in
            return Void()
        }
    }
    
    func context(post: MastodonPost) -> Promise<MastodonPostContext> {
        return self.get("statuses/\(post.id.string)/context").then { res -> MastodonPostContext in
            return try MastodonPostContext.decode(json: res)
        }
    }
    
    func reports(account: MastodonAccount, comment: String = "", forward: Bool = false, posts: [MastodonPost]) -> Promise<Void> {
        return self.post("reports", params: [
            "account_id": account.id.raw,
            "comment": comment,
            "forward": forward,
            "status_ids": posts.map({$0.id.raw})
        ]).then { res in
                return Void()
        }
    }
    
    func timeline(_ type: MastodonTimelineType, limit:Int? = nil, since: MastodonPost? = nil, max: MastodonPost? = nil) -> Promise<[MastodonPost]>{
        var params = type.params
        if let limit = limit {
            params["limit"] = limit
        }
        if let since = since {
            print(since, since.id, since.id.string)
            params["since_id"] = since.id.string
        }
        if let max = max {
            params["max_id"] = max.id.string
        }
        return self.get(type.endpoint, params: params).then { res in
            return try res.arrayValue.map({try MastodonPost.decode(json: $0)})
        }
    }
}

class MastodonTimelineType {
    let endpoint: String
    let params: [String: Any]
    
    static let home = MastodonTimelineType(endpoint: "timelines/home")
    static let local = MastodonTimelineType(endpoint: "timelines/public", params: ["local": "true"])
    static func user(_ account: MastodonAccount, pinned: Bool = false) -> MastodonTimelineType {
        var params: [String: Any] = [:]
        if pinned {
            params["pinned"] = 1
        }
        return MastodonTimelineType(endpoint: "accounts/\(account.id.string)/statuses", params: params)
    }
    static func list(_ list: MastodonList) -> MastodonTimelineType {
        return MastodonTimelineType(endpoint: "timelines/list/\(list.id.string)")
    }
    
    init(endpoint: String, params: [String: Any] = [:]) {
        self.endpoint = endpoint
        self.params = params
    }
}
