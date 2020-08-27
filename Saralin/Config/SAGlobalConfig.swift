//
//  SAGlobalConfig.swift
//  Saralin
//
//  Created by zhang on 10/21/16.
//  Copyright © 2016 zaczh. All rights reserved.
//

import UIKit


enum SAUserDefaultsKey: String {
    case lastDateClearedDiskCache = "me.zaczh.saralin.lastDateClearedDiskCache"
    case lastDateEulaBeenAgreed = "me.zaczh.saralin.lastDateEulaBeenAgreed"
    case lastDateWatchingListIntroductionBeenShown = "me.zaczh.saralin.lastDateWatchingListIntroductionBeenShown"
    case lastDateRequestedReviewInAppStore = "me.zaczh.saralin.lastDateRequestedReviewInAppStore"
    case appVersionOfLastLagacyFileMigration = "me.zaczh.saralin.appVersionOfLastLagacyFileMigration"
}


// MARK: - Some string constants
struct SAGlobalConfig {
    
    let pc_useragent_string = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_12_5) AppleWebKit/603.2.4 (KHTML, like Gecko) Version/10.1.1 Safari/603.2.4"
    
    let mobile_useragent_string = "Mozilla/5.0 (iPhone; CPU iPhone OS 9_1 like Mac OS X) AppleWebKit/601.1.46 (KHTML, like Gecko) Version/9.0 Mobile/13B143 Safari/601.1"
    
    let app_store_link = "https://apps.apple.com/cn/app/saralin/id1086444812"
    
    let app_version_string = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as! String

    let mahjong_emoji_domain = "static.saraba1st.com"
    
    let forum_domain = "bbs.saraba1st.com"
    
    let forum_sub_domains = ["bbs.saraba1st.com", "bbs.stage1.cc", "www.stage1st.com", "www.saraba1st.com", "static.saraba1st.com"]
    
    // This must be paired with previous one
    let forum_TLDs = ["saraba1st.com", "stage1.cc", "stage1st.com"]

    // NOTE: some domain (bbs.stage1.cc) does not end with `2b`
    let forum_base_url_alternative = ["https://bbs.saraba1st.com/2b/", "http://bbs.stage1.cc/", "http://www.stage1st.com/2b/"]
    
    // the forum_base_url is the base url for doing threads fetching, threads contents fetching, etc.
    // it is not the forum domain.
    let forum_base_url = "https://bbs.saraba1st.com/2b/"
    
    // avatar domain may be different from forum
    let avatar_base_url = "https://avatar.saraba1st.com/"
    
    let forum_app_api_domain = "https://app.saraba1st.com/"

    var profile_url_template: String { return forum_base_url + "space-uid-%{UID}.html" }
    
    var user_threads_url_template: String { return forum_base_url + "home.php?mod=space&uid=%{UID}&do=thread&view=me&from=space" }
    
    var forum_url: String { return forum_base_url + "forum.php" }
    
    var login_url: String { return forum_base_url + "member.php?mod=logging&action=login&mobile=no" }
    
    var register_url: String { return forum_base_url + "member.php?mod=register&mobile=1" }
    
    // Signature
    var signature: String { return "\n\n发自我的\(UIDevice.current.localizedModel) via [url=\(app_store_link)]Saralin \(app_version_string)[/url]\n" }
        
    // how many replies we want to get per fetch
    // this is the default value
    let number_of_replies_per_page = 30
    
    let number_of_threads_per_page = 50
    
    // how frequently when do background fetch
    let background_fetch_interval = Double(120.0)
    
    let online_config_file_url = "https://raw.githubusercontent.com/zaczh/SaralinPub/master/app_online_config.plist"
    
    // how many days of log files to keep
    let log_file_days_to_keep = 3
    
    let project_source_code_url = "https://github.com/zaczh/SaralinPub"
    
    let developer_imessage_address = "jhzhangdev@gmail.com"
    
    let developer_email_address = "jhzhangdev@gmail.com"
}
