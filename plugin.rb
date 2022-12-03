# frozen_string_literal: true

# name: optimized move posts notice
# about:
# version: 0.1.3
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
            count: posts.length,
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
      @original_topic.update_status('visible', false, @user)
      super
    end

    def close_topic_and_schedule_deletion
      @original_topic.update_status('closed', true, @user)
  
      days_to_deleting = SiteSetting.delete_merged_stub_topics_after_days
      if days_to_deleting > 0
        @original_topic.set_or_create_timer(
          TopicTimer.types[:delete],
          days_to_deleting * 24,
          by_user: Discourse.system_user
        )
      end
    end

  end

  class ::PostMover
    prepend OverridingPostMover
  end
end