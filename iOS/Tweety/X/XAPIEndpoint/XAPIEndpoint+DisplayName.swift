//
//  XAPIEndpoint+DisplayName.swift
//  Tweety
//
//  Created by Abdulaziz Albahar on 1/16/26.
//

import Foundation

extension XAPIEndpoint {
    /// User-friendly display name for the endpoint, shown in conversation UI
    var displayName: String {
        switch self {
        // MARK: - Posts/Tweets
        case .createTweet: return "Create Tweet"
        case .replyToTweet: return "Reply to Tweet"
        case .quoteTweet: return "Quote Tweet"
        case .createPollTweet: return "Create Poll"
        case .deleteTweet: return "Delete Tweet"
        case .editTweet: return "Edit Tweet"
        case .getTweet: return "Get Tweet"
        case .getTweets: return "Get Tweets"
        case .getUserTweets: return "Get User's Tweets"
        case .getUserMentions: return "Get Mentions"
        case .getHomeTimeline: return "Get Home Timeline"
        case .searchRecentTweets: return "Search Recent Tweets"
        case .searchAllTweets: return "Search All Tweets"
        case .getRecentTweetCounts: return "Get Recent Tweet Counts"
        case .getAllTweetCounts: return "Get All Tweet Counts"

        // MARK: - Users
        case .getUserById: return "Get User by ID"
        case .getUserByUsername: return "Get User by Username"
        case .getUsersById: return "Get Users by ID"
        case .getUsersByUsername: return "Get Users by Username"
        case .getAuthenticatedUser: return "Get My Profile"
        case .getUserFollowing: return "Get Following"
        case .followUser: return "Follow User"
        case .unfollowUser: return "Unfollow User"
        case .getUserFollowers: return "Get Followers"
        case .getMutedUsers: return "Get Muted Users"
        case .muteUser: return "Mute User"
        case .unmuteUser: return "Unmute User"
        case .getBlockedUsers: return "Get Blocked Users"
        case .blockUserDMs: return "Block User's DMs"
        case .unblockUserDMs: return "Unblock User's DMs"

        // MARK: - Likes
        case .getLikingUsers: return "Get Liking Users"
        case .likeTweet: return "Like Tweet"
        case .unlikeTweet: return "Unlike Tweet"
        case .getUserLikedTweets: return "Get Liked Tweets"

        // MARK: - Retweets
        case .getRetweetedBy: return "Get Retweeted By"
        case .retweet: return "Retweet"
        case .unretweet: return "Undo Retweet"
        case .getRetweets: return "Get Retweets"
//        case .getRepostsOfMe: return "Get My Reposts"

        // MARK: - Lists
        case .createList: return "Create List"
        case .deleteList: return "Delete List"
        case .updateList: return "Update List"
        case .getList: return "Get List"
        case .getListMembers: return "Get List Members"
        case .addListMember: return "Add to List"
        case .removeListMember: return "Remove from List"
        case .getListTweets: return "Get List Tweets"
        case .getListFollowers: return "Get List Followers"
        case .pinList: return "Pin List"
        case .unpinList: return "Unpin List"
        case .getPinnedLists: return "Get Pinned Lists"
        case .getOwnedLists: return "Get My Lists"
        case .getFollowedLists: return "Get Followed Lists"
        case .followList: return "Follow List"
        case .unfollowList: return "Unfollow List"
        case .getListMemberships: return "Get List Memberships"

        // MARK: - Direct Messages
        case .createDMConversation: return "Create DM Conversation"
        case .sendDMToConversation: return "Send DM to Conversation"
        case .sendDMToParticipant: return "Send DM"
        case .getDMEvents: return "Get DM Events"
        case .getConversationDMs: return "Get Conversation DMs"
        case .getConversationDMsByParticipant: return "Get Conversation with User"
        case .deleteDMEvent: return "Delete DM"
        case .getDMEventDetails: return "Get DM Details"

        // MARK: - Bookmarks
        case .addBookmark: return "Add Bookmark"
        case .removeBookmark: return "Remove Bookmark"
        case .getUserBookmarks: return "Get Bookmarks"

        // MARK: - Trends
        case .getPersonalizedTrends: return "Get Trending Topics"

        // MARK: - Community Notes
        case .createNote: return "Create Community Note"
        case .deleteNote: return "Delete Community Note"
        case .evaluateNote: return "Evaluate Community Note"
        case .getNotesWritten: return "Get My Community Notes"
        case .getPostsEligibleForNotes: return "Get Posts Eligible for Notes"

        // MARK: - Media
        case .uploadMedia: return "Upload Media"
        case .getMediaStatus: return "Get Media Status"
        case .initializeChunkedUpload: return "Start Media Upload"
        case .appendChunkedUpload: return "Upload Media Chunk"
        case .finalizeChunkedUpload: return "Finalize Media Upload"
        case .createMediaMetadata: return "Add Media Metadata"
        case .getMediaAnalytics: return "Get Media Analytics"

        // MARK: - News
        case .getNewsById: return "Get News Story"
        case .searchNews: return "Search News"
        }
    }
}
