module Danbooru
  class Configuration
    # The version of this Danbooru.
    def version
      "2.0.0"
    end
    
    # The name of this Danbooru.
    def app_name
      "Danbooru"
    end
    
    # The default name to use for anyone who isn't logged in.
    def default_guest_name
      "Anonymous"
    end
    
    # This is a salt used to make dictionary attacks on account passwords harder.
    def password_salt
      "choujin-steiner"
    end
    
    # Set to true to allow new account signups.
    def enable_signups?
      true
    end
    
    # Set to true to give all new users privileged access.
    def start_as_privileged?
      false
    end
    
    # Set to true to give all new users contributor access.
    def start_as_contributor?
      false
    end
    
    # What method to use to store images.
    # local_flat: Store every image in one directory.
    # local_hierarchy: Store every image in a hierarchical directory, based on the post's MD5 hash. On some file systems this may be faster.
    def image_store
      :local_flat
    end
    
    # Thumbnail size
    def small_image_width
      150
    end
    
    # Medium resize image width
    def medium_image_width
      500
    end
    
    # Large resize image width
    def large_image_width
      1024
    end
    
    # When calculating statistics based on the posts table, gather this many posts to sample from.
    def post_sample_size
      300
    end
    
    # List of memcached servers
    def memcached_servers
      %w(localhost:11211)
    end
    
    # After a post receives this many comments, new comments will no longer bump the post in comment/index.
    def comment_threshold
      40
    end
    
    # Members cannot post more than X comments in an hour.
    def member_comment_limit
      2
    end

    # Determine who can see a post.    
    def can_see_post?(post, user)
      true
    end
    
    # Determines who can see ads.
    def can_see_ads?(user)
      false
    end
    
    # This is required for Rails 2.0.
    def session_secret_key
      "This should be at least 30 characters long"
    end
    
    # Users cannot search for more than X regular tags at a time.
    def tag_query_limit
      6
    end
    
    # Max number of posts to cache
    def tag_subscription_post_limit
      200
    end

    # Max number of tag subscriptions per user
    def max_tag_subscriptions
      5
    end
    
    # The name of the server the app is hosted on.
    def server_host
      Socket.gethostname
    end
    
    # Returns a hash mapping various tag categories to a numerical value.
    # Be sure to update the reverse_tag_category_mapping also.
    def tag_category_mapping
      @tag_category_mapping ||= {
        "general" => 0,
        "gen" => 0,

        "artist" => 1,
        "art" => 1,

        "copyright" => 3,
        "copy" => 3,
        "co" => 3,

        "character" => 4,
        "char" => 4,
        "ch" => 4
      }
    end
    
    # Returns a hash maping numerical category values to their
    # string equivalent. Be sure to update the tag_category_mapping also.
    def reverse_tag_category_mapping
      @reverse_tag_category_mapping ||= {
        0 => "General",
        1 => "Artist",
        3 => "Copyright",
        4 => "Character"
      }
    end
  end
end