module T
  module RequestableAPI
    # Convert the resources of the x gem into the hashes the command classes print
    module Presenters
    private

      def user_hash(user)
        return if user.nil?

        hash = {
          "id" => user.id,
          "screen_name" => user.username,
          "name" => user.name,
          "created_at" => user.created_at,
          "verified" => user.verified,
          "protected" => user.protected,
          "description" => user.description,
          "location" => user.location,
          "url" => user.url,
          "statuses_count" => user.post_count,
          "favorites_count" => user.like_count,
          "listed_count" => user.listed_count,
          "friends_count" => user.following_count,
          "followers_count" => user.followers_count,
        }
        pinned = user.pinned_post
        hash["status"] = tweet_hash(pinned) if expanded?(pinned)
        hash
      end

      def tweet_hash(post)
        return if post.nil?

        text = display_text(post)
        hash = {
          "id" => post.id,
          "id_str" => post.id.to_s,
          "text" => text,
          "full_text" => text,
          "created_at" => post.created_at,
          "source" => post.source,
          "in_reply_to_status_id" => post.replied_to&.id,
          "expanded_text" => expanded_text(post),
          "retweet_count" => post.repost_count,
          "favorite_count" => post.like_count,
          "url" => post.permalink,
          "user" => author_hash(post.author),
        }
        apply_tweet_geo(hash, post)
        hash
      end

      # An author the response did not expand is known only by identifier
      def author_hash(author)
        hash = user_hash(author)
        hash["screen_name"] ||= author.id.to_s if hash
        hash
      end

      def list_hash(list)
        return if list.nil?

        hash = {
          "id" => list.id,
          "slug" => list.name,
          "name" => list.name,
          "created_at" => list.created_at,
          "description" => list.description,
          "member_count" => list.member_count,
          "subscriber_count" => list.follower_count,
          "mode" => list_mode(list),
          "uri" => list.permalink,
        }
        owner = list.owner
        return hash if owner.nil?

        hash["user"] = user_hash(owner)
        hash["full_name"] = "@#{hash['user']['screen_name']}/#{list.name}"
        hash
      end

      def dm_hash(message, recipient_id, recipient)
        {
          "id" => message.id,
          "text" => message.text.to_s,
          "full_text" => message.text.to_s,
          "created_at" => message.created_at,
          "sender_id" => message.sender_id.to_i,
          "recipient_id" => recipient_id.to_i,
          "recipient" => user_hash(recipient) || {},
        }
      end

      # The text, with an included repost expanded to the "RT @username: text" form the commands print
      def display_text(post)
        original = post.reposted
        return post.text if original.nil? || original.text.nil?

        "#{repost_prefix(post, original)}#{original.text}"
      end

      # The display text with every shortened link replaced by the URL it stands for
      def expanded_text(post)
        original = post.reposted
        return post.expanded_text if original.nil? || original.text.nil?

        "#{repost_prefix(post, original)}#{original.expanded_text}"
      end

      # The "RT @username: " the repost's own text begins with, or one built from the original's author
      def repost_prefix(post, original) = post.text.to_s[/\ART @\w{1,15}: /] || "RT @#{original.author&.username || original.author_id}: "

      def apply_tweet_geo(hash, post)
        place = post.place
        hash["place"] = place.attrs if expanded?(place)
        hash["geo"] = {"type" => "Point", "coordinates" => post.coordinates} if place.nil? && post.coordinates
      end

      def list_mode(list)
        return if list.private.nil?

        list.private? ? "private" : "public"
      end

      # A referenced resource is expanded when the response included it, rather than a stub holding only its identifier
      def expanded?(resource) = !(resource.nil? || resource.stub?)
    end
  end
end
