# frozen_string_literal: true

# name: optimized move posts notice
# about:
# version: 0.1.1
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
            topic_link: "[#{original_topic.title}](#{original_topic.relative_url})"
          )
        end
    
        post_type = @move_to_pm ? Post.types[:whisper] : Post.types[:small_action]
        destination_topic.add_moderator_post(
          user, message,
          post_type: post_type,
          action_code: "optimized_move_posts",
        )
    end
  end

  class ::PostMover
    prepend OverridingPostMover
  end
end