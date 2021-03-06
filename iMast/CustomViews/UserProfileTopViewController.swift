//
//  UserProfileTopViewController.swift
//  iMast
//
//  Created by rinsuki on 2017/07/07.
//  Copyright © 2017年 rinsuki. All rights reserved.
//

import UIKit
import SwiftyJSON
import Accounts
import SafariServices

class UserProfileTopViewController: UITableViewController {

    @IBOutlet weak var tootCell: UITableViewCell!
    @IBOutlet weak var userIconView: UIImageView!
    @IBOutlet weak var userNameView: UILabel!
    @IBOutlet weak var userScreenNameView: UILabel!
    @IBOutlet weak var followingCell: UITableViewCell!
    @IBOutlet weak var followersCell: UITableViewCell!
    @IBOutlet weak var createdAtCell: UITableViewCell!
    @IBOutlet weak var tootDaysCell: UITableViewCell!
    @IBOutlet weak var createdAtSabunCell: UITableViewCell!
    @IBOutlet weak var moreButton: UIBarButtonItem!
    @IBOutlet weak var relationShipLabel: UILabel!
    var loadAfter = false
    var isLoaded = false
    var user: MastodonAccount?
    var externalServiceLinks: [(name: String, userId: String?, url: URL)] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Uncomment the following line to preserve selection between presentations
        // self.clearsSelectionOnViewWillAppear = false

        // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
        // self.navigationItem.rightBarButtonItem = self.editButtonItem()
        isLoaded = true
        if loadAfter {
            loadAfter = false
            load(user: user!)
        }
        refreshControl = UIRefreshControl()
        refreshControl?.addTarget(self, action: #selector(self.reload(sender:)), for: .valueChanged)
    }
    
    @objc func reload(sender: UIRefreshControl) {
        MastodonUserToken.getLatestUsed()!.getAccount(id: user!.id).then { res in
            print(res)
            self.load(user: res)
            self.refreshControl?.endRefreshing()
        }
    }
    
    func load(user: MastodonAccount) {
        self.user = user
        if isLoaded == false {
            loadAfter = true
            return
        }
        self.userIconView.sd_setImage(with: URL(string: user.avatarUrl))
        self.userNameView.text = (user.name != "" ? user.name : user.screenName).emojify()
        self.userScreenNameView.text = "@"+user.acct
        self.tootCell.detailTextLabel?.text = numToCommaString(user.postsCount)
        self.followingCell.detailTextLabel?.text = numToCommaString(user.followingCount)
        self.followersCell.detailTextLabel?.text = numToCommaString(user.followersCount)
        let createdAt = user.createdAt
        self.createdAtCell.detailTextLabel?.text = DateUtils.stringFromDate(
            createdAt,
            format: "yyyy/MM/dd HH:mm:ss"
        )
        self.tootDaysCell.detailTextLabel?.text = numToCommaString(-(user.postsCount/Int(min(-1, createdAt.timeIntervalSinceNow/60/60/24))))
        self.createdAtSabunCell.detailTextLabel?.text = numToCommaString(-Int(createdAt.timeIntervalSinceNow/60/60/24)) + "日"
        MastodonUserToken.getLatestUsed()?.getRelationship([user]).then({ (relationships) in
            let relationship = relationships[0]
            let relationshipOld: Bool = Defaults[.followRelationshipsOld]
            if relationship.following && relationship.followed_by {
                self.relationShipLabel.text = "関係: " + (relationshipOld ? "両思い" : "相互フォロー")
            }
            if relationship.following && !relationship.followed_by {
                self.relationShipLabel.text = "関係: " + (relationshipOld ? "片思い" : "フォローしています")
            }
            if !relationship.following && relationship.followed_by {
                self.relationShipLabel.text = "関係: " + (relationshipOld ? "片思われ" : "フォローされています")
            }
            if !relationship.following && !relationship.followed_by {
                self.relationShipLabel.text = "関係: 無関係"
            }
            if user.acct == MastodonUserToken.getLatestUsed()?.screenName {
                self.relationShipLabel.text = "関係: それはあなたです！"
            }
            if relationship.requested {
                self.relationShipLabel.text! += " (フォローリクエスト中)"
            }
            if relationship.blocking {
                self.relationShipLabel.text! += " (ブロック中)"
            }
            if relationship.muting {
                self.relationShipLabel.text! += " (ミュート中)"
            }
            if relationship.domain_blocking {
                self.relationShipLabel.text! += " (インスタンスミュート中)"
            }
        })
        
        self.externalServiceLinks = []
        
        if let niconicoUrl = user.niconicoUrl {
            let niconicoId = niconicoUrl.absoluteString.components(separatedBy: "/").last
            self.externalServiceLinks.append((name: "niconico", userId: niconicoId != nil ? "user/"+niconicoId! : nil, url: niconicoUrl))
        }
    }

    @IBAction func moreButtonTapped(_ sender: Any) {
        guard let user = self.user else {
            return
        }
        let myScreenName = "@"+(MastodonUserToken.getLatestUsed()!.screenName!)
        MastodonUserToken.getLatestUsed()?.getRelationship([user]).then({ (relationships) in
            let relationship = relationships[0]
            let screenName = "@"+user.acct
            let actionSheet = UIAlertController(title: "アクション", message: screenName, preferredStyle: UIAlertControllerStyle.actionSheet)
            actionSheet.popoverPresentationController?.barButtonItem = self.moreButton
            actionSheet.addAction(UIAlertAction(title: "共有", style: UIAlertActionStyle.default, handler: {
                (action: UIAlertAction!) in
                let activityItems:[Any] = [
                    (user.name != "" ? user.name : user.screenName).emojify()+"さんのプロフィール - Mastodon",
                    NSURL(string: user.url)!
                ]
                let activityVC = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
                activityVC.popoverPresentationController?.sourceView = self.moreButton.value(forKey: "view") as? UIView
                activityVC.popoverPresentationController?.sourceRect = (self.moreButton.value(forKey: "view") as! UIView).bounds
                self.present(activityVC, animated: true, completion: nil)
            }))
            if myScreenName != screenName {
                if !relationship.following { // 未フォロー
                    if !relationship.requested { // 未フォロー
                        actionSheet.addAction(UIAlertAction(title: "フォローする", style: UIAlertActionStyle.default, handler: {
                            (action: UIAlertAction!) in
                            MastodonUserToken.getLatestUsed()?.follow(account: user).then({ (res) in
                                self.reload(sender: self.refreshControl!)
                            })
                        }))
                    } else {// フォローリクエスト中
                        actionSheet.addAction(UIAlertAction(title: "フォローリクエストの撤回", style: UIAlertActionStyle.destructive, handler: {
                            (action: UIAlertAction!) in
                            self.confirm(title: "確認", message: screenName+"へのフォローリクエストを撤回しますか?", okButtonMessage: "撤回", style: .destructive).then({ (result) in
                                if !result {
                                    return
                                }
                                MastodonUserToken.getLatestUsed()?.unfollow(account: user).then({ (res) in
                                    self.reload(sender: self.refreshControl!)
                                })
                            })
                        }))
                    }
                } else { // フォロー済み
                    actionSheet.addAction(UIAlertAction(title: "フォロー解除", style: UIAlertActionStyle.destructive, handler: {
                        (action: UIAlertAction!) in
                        self.confirm(title: "確認", message: screenName+"のフォローを解除しますか?", okButtonMessage: "解除", style: .destructive).then({ (result) in
                            if !result {
                                return
                            }
                            MastodonUserToken.getLatestUsed()?.unfollow(account: user).then({ (res) in
                                self.reload(sender: self.refreshControl!)
                            })
                        })
                    }))
                }
                if !relationship.muting { // 未ミュート
                    actionSheet.addAction(UIAlertAction(title: "ミュート", style: UIAlertActionStyle.destructive, handler: { (action) in
                        self.confirm(title: "確認", message: screenName+"をミュートしますか?", okButtonMessage: "ミュート", style: .destructive).then({ (result) in
                            if !result {
                                return
                            }
                            MastodonUserToken.getLatestUsed()?.mute(account: user).then({ (res) in
                                self.reload(sender: self.refreshControl!)
                            })
                        })
                    }))
                } else {
                    actionSheet.addAction(UIAlertAction(title: "ミュート解除", style: UIAlertActionStyle.destructive, handler: { (action) in
                        self.confirm(title: "確認", message: screenName+"のミュートを解除しますか?", okButtonMessage: "ミュート解除", style: .destructive).then({ (result) in
                            if !result {
                                return
                            }
                            MastodonUserToken.getLatestUsed()?.unmute(account: user).then({ (res) in
                                self.reload(sender: self.refreshControl!)
                            })
                        })
                    }))
                }
                if !relationship.blocking { // 未ブロック
                    actionSheet.addAction(UIAlertAction(title: "ブロック", style: UIAlertActionStyle.destructive, handler: { (action) in
                        self.confirm(title: "確認", message: screenName+"をブロックしますか?", okButtonMessage: "ブロック", style: .destructive).then({ (result) in
                            if !result {
                                return
                            }
                            MastodonUserToken.getLatestUsed()?.block(account: user).then({ (res) in
                                self.reload(sender: self.refreshControl!)
                            })
                        })
                    }))
                } else {
                    actionSheet.addAction(UIAlertAction(title: "ブロック解除", style: UIAlertActionStyle.destructive, handler: { (action) in
                        self.confirm(title: "確認", message: screenName+"のブロックを解除しますか?", okButtonMessage: "ブロック解除", style: .destructive).then({ (result) in
                            if !result {
                                return
                            }
                            MastodonUserToken.getLatestUsed()?.unblock(account: user).then({ (res) in
                                self.reload(sender: self.refreshControl!)
                            })
                        })
                        
                    }))
                }
            } else {
                actionSheet.addAction(UIAlertAction(title: "名刺", style: .default, handler: { action in
                    let storyboard = UIStoryboard(name: "ProfileCard", bundle: nil)
                    let newVC = storyboard.instantiateInitialViewController()! as! ProfileCardViewController
                    newVC.user = user
                    self.navigationController?.pushViewController(newVC, animated: true)
                }))
                if user.isLocked {
                    actionSheet.addAction(UIAlertAction(title: "フォローリクエスト一覧", style: .default) { _ in
                        MastodonUserToken.getLatestUsed()?.followRequests().then { res in
                            let newVC = FollowRequestsListTableViewController()
                            newVC.followRequests = res
                            self.navigationController?.pushViewController(newVC, animated: true)
                        }
                    })
                }
            }
            actionSheet.addAction(UIAlertAction(title: "キャンセル", style: UIAlertActionStyle.cancel))
            self.present(actionSheet, animated: true, completion: nil)
        })
    }
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "tootList" {
            let nextVC = segue.destination as! UserTimeLineTableViewController
            nextVC.user = self.user
        }
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section != 2 {
            return super.tableView(tableView, cellForRowAt: indexPath)
        }
        
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil)

        // Configure the cell...

        let externalService = self.externalServiceLinks[indexPath.row]
        
        cell.textLabel?.text = externalService.name
        cell.detailTextLabel?.text = externalService.userId
        cell.accessoryType = .disclosureIndicator
        
        cell.setNeedsLayout()
        cell.layoutIfNeeded()
        
        return cell
    }
    
    override func tableView(_ tableView: UITableView, indentationLevelForRowAt indexPath: IndexPath) -> Int {
        return 0
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section != 2 {
            return super.tableView(tableView, numberOfRowsInSection: section)
        }
        return self.externalServiceLinks.count
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if indexPath.section != 2 {
//            super.tableView(tableView, didSelectRowAt: indexPath)
            return
        }
        
        let safariVC = SFSafariViewController(url: self.externalServiceLinks[indexPath.row].url)
        self.present(safariVC, animated: true, completion: nil)
    }

    /*
    // Override to support conditional editing of the table view.
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        // Return false if you do not want the specified item to be editable.
        return true
    }
    */

    /*
    // Override to support editing the table view.
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            // Delete the row from the data source
            tableView.deleteRows(at: [indexPath], with: .fade)
        } else if editingStyle == .insert {
            // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
        }    
    }
    */

    /*
    // Override to support rearranging the table view.
    override func tableView(_ tableView: UITableView, moveRowAt fromIndexPath: IndexPath, to: IndexPath) {

    }
    */

    /*
    // Override to support conditional rearranging of the table view.
    override func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
        // Return false if you do not want the item to be re-orderable.
        return true
    }
    */

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}

func openUserProfile(user: MastodonAccount) -> UserProfileTopViewController {
    let storyboard = UIStoryboard(name: "UserProfile", bundle: nil)
    let newVC = storyboard.instantiateInitialViewController() as! UserProfileTopViewController
    newVC.load(user: user)
    return newVC
}
