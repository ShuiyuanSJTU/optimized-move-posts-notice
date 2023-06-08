# frozen_string_literal: true

# name: optimized-move-posts-notice
# about:
# version: 0.1.6
# authors: pangbo
# url: https://github.com/ShuiyuanSJTU/optimized-move-posts-notice
# required_version: 2.7.0
# transpile_js: true

enabled_site_setting :optimized_move_posts_notice_enabled

PLUGIN_NAME ||= 'optimized_move_posts_notice'

after_initialize do
  module OverridingPostMover
    def move_posts_to(topic)
        Guardian.new(user).ensure_can_see! topic
        @destination_topic = topic
        create_moderator_post_in_destination_topic unless destination_topic.posts_count == 0
        super
    end

    def create_moderator_post_in_destination_topic
        message = I18n.with_locale(SiteSetting.default_locale) do
          I18n.t(
            "optimized_move_posts_notice.moderator_post_destination",
            # topic_link: "[#{original_topic.title}](#{original_topic.relative_url})"
            topic_link: "#{original_topic.title}"
          )
        end
    
        post_type = @move_to_pm ? Post.types[:whisper] : Post.types[:small_action]
        @moderator_post_in_destination_topic = destination_topic.add_moderator_post(
          Discourse.system_user, 
          message,
          post_type: post_type,
          action_code: "optimized_move_posts",
        )
    end

    def close_topic_and_schedule_deletion
      @original_topic.update_status('closed', true, @user)
      @original_topic.update_status('visible', false, @user)
  
      days_to_deleting = SiteSetting.delete_merged_stub_topics_after_days
      if days_to_deleting > 0
        @original_topic.set_or_create_timer(
          TopicTimer.types[:delete],
          days_to_deleting * 24,
          # change: change by_user to system_user, so that tl4 users can also delete
          by_user: Discourse.system_user
        )
      end
    end
    
    def create_moderator_post_in_original_topic
      move_type_str = PostMover.move_types[@move_type].to_s
      move_type_str.sub!("topic", "message") if @move_to_pm
  
      # change: use @new_posts
      message = I18n.with_locale(SiteSetting.default_locale) do
        I18n.t(
          "move_posts.#{move_type_str}_moderator_post",
          count: posts.length,
          topic_link: @new_posts.first.is_first_post? ?
            "[#{destination_topic.title}](#{destination_topic.relative_url})" :
            "[#{destination_topic.title}](#{@new_posts.first.url})"
        )
      end
      post_type = @move_to_pm ? Post.types[:whisper] : Post.types[:small_action]
      original_topic.add_moderator_post(
        user, message,
        post_type: post_type,
        action_code: "split_topic",
        post_number: @first_post_number_moved
      )
    end

    def move_each_post
      max_post_number = destination_topic.max_post_number + 1
  
      @post_creator = nil
      @move_map = {}
      @reply_count = {}
      posts.each_with_index do |post, offset|
        @move_map[post.post_number] = offset + max_post_number
  
        if post.reply_to_post_number.present?
          @reply_count[post.reply_to_post_number] = (@reply_count[post.reply_to_post_number] || 0) + 1
        end
      end
  
      # change: add an array to store new posts
      @new_posts = posts.collect do |post|
        metadata = movement_metadata(post)
        new_post = post.is_first_post? ? create_first_post(post) : move(post)
  
        store_movement(metadata, new_post)
  
        if @move_to_pm && !destination_topic.topic_allowed_users.exists?(user_id: post.user_id)
          destination_topic.topic_allowed_users.create!(user_id: post.user_id)
        end
        new_post
      end
  
      move_incoming_emails
      move_notifications
      update_reply_counts
      update_quotes
      move_first_post_replies
      delete_post_replies
      delete_invalid_post_timings
      copy_first_post_timings
      move_post_timings
      copy_topic_users
    end
  end

  class ::PostMover
    prepend OverridingPostMover
  end
end
