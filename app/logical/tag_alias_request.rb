class TagAliasRequest
  include ActiveModel::Validations

  attr_reader :antecedent_name, :consequent_name, :reason, :skip_secondary_validations, :tag_alias, :forum_topic, :skip_forum

  validate :validate_tag_alias
  validate :validate_forum_topic

  def self.topic_title(antecedent_name, consequent_name)
    "Tag alias: #{antecedent_name} -> #{consequent_name}"
  end

  def self.command_string(antecedent_name, consequent_name, id = nil)
    if id
      return "[ta:#{id}]"
    end

    "create alias [[#{antecedent_name}]] -> [[#{consequent_name}]]"
  end

  def initialize(attributes)
    @antecedent_name = attributes[:antecedent_name].strip.tr(" ", "_")
    @consequent_name = attributes[:consequent_name].strip.tr(" ", "_")
    @reason = attributes[:reason]
    self.skip_secondary_validations = attributes[:skip_secondary_validations]
    self.skip_forum = attributes[:skip_forum]
  end

  def create
    return false if invalid?

    TagAlias.transaction do
      @tag_alias = build_tag_alias
      @tag_alias.save

      unless skip_forum
        @forum_topic = build_forum_topic(@tag_alias.id)
        @forum_topic.save

        @tag_alias.forum_topic_id = @forum_topic.id
        @tag_alias.forum_post_id = @forum_topic.posts.first.id
        @tag_alias.save
      end
    end
  end

  def build_tag_alias
    x = TagAlias.new(
        :antecedent_name => antecedent_name,
        :consequent_name => consequent_name,
        :skip_secondary_validations => skip_secondary_validations
    )
    x.status = "pending"
    x
  end

  def build_forum_topic(tag_alias_id)
    ForumTopic.new(
        :title => TagAliasRequest.topic_title(antecedent_name, consequent_name),
        :original_post_attributes => {
            :body => TagAliasRequest.command_string(antecedent_name, consequent_name, tag_alias_id) + "\n\nReason: #{reason}"
        },
        :category_id => 1
    )
  end

  def validate_tag_alias
    ta = @tag_alias || build_tag_alias

    if ta.invalid?
      self.errors.add(:base, ta.errors.full_messages.join("; "))
      return false
    end
  end

  def validate_forum_topic
    return if skip_forum
    ft = @forum_topic || build_forum_topic(nil)
    if ft.invalid?
      self.errors.add(:base, ft.errors.full_messages.join("; "))
      return false
    end
  end

  def skip_secondary_validations=(v)
    @skip_secondary_validations = v.to_s.truthy?
  end

  def skip_forum=(v)
    @skip_forum = v.to_s.truthy?
  end
end
