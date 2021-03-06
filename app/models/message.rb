# BetterMeans - Work 2.0
# Copyright (C) 2006-2011  See readme for details and license#

class Message < ActiveRecord::Base
  belongs_to :board
  belongs_to :author, :class_name => 'User', :foreign_key => 'author_id'
  acts_as_tree :counter_cache => :replies_count, :order => "#{Message.table_name}.created_at ASC"
  acts_as_attachable
  belongs_to :last_reply, :class_name => 'Message', :foreign_key => 'last_reply_id'

  acts_as_searchable :columns => ['subject', 'content'],
                     :include => {:board => :project},
                     :project_key => 'project_id',
                     :date_column => "#{table_name}.created_at"

  acts_as_event :title => Proc.new {|o| "#{o.board.name}: #{o.subject}"},
                :description => :content,
                :type => Proc.new {|o| o.parent_id.nil? ? 'message' : 'reply'},
                :url => Proc.new {|o| {:controller => 'messages', :action => 'show', :board_id => o.board_id}.merge(o.parent_id.nil? ? {:id => o.id} :
                                                                                                                                       {:id => o.parent_id, :anchor => "message-#{o.id}"})}
  acts_as_watchable

  attr_protected :locked, :sticky
  validates_presence_of :board, :subject, :content
  validates_length_of :subject, :maximum => 255

  after_create :add_author_as_watcher
  after_save :send_mentions

  def project_id # spec_me cover_me heckle_me
    board.project.id
  end

  def visible?(user=User.current) # spec_me cover_me heckle_me
    !user.nil? && user.allowed_to?(:view_messages, project)
  end

  def validate_on_create # spec_me cover_me heckle_me
    # Can not reply to a locked topic
    errors.add_to_base 'Topic is locked' if root.locked? && self != root
  end

  def after_create # spec_me cover_me heckle_me
    if parent
      parent.reload.update_attribute(:last_reply_id, self.id)
    end
    board.reset_counters!
  end

  def send_mentions # spec_me cover_me heckle_me
    Mention.parse(self, self.author_id)
  end

  def mention(mentioner_id, mentioned_id, mention_text) # spec_me cover_me heckle_me
    Notification.create :recipient_id => mentioned_id,
                        :variation => 'mention',
                        :params => {:mention_text => self.content,
                                    :url => {:controller => "messages", :action => "show", :board_id => self.board_id, :id => self.id},
                                    :title => self.subject},
                        :sender_id => mentioner_id,
                        :source_id => self.id,
                        :source_type => "Message"
  end


  def after_update # spec_me cover_me heckle_me
    if board_id_changed?
      Message.update_all("board_id = #{board_id}", ["id = ? OR parent_id = ?", root.id, root.id])
      Board.reset_counters!(board_id_was)
      Board.reset_counters!(board_id)
    end
  end

  def after_destroy # spec_me cover_me heckle_me
    board.reset_counters!
  end

  def sticky=(arg) # spec_me cover_me heckle_me
    write_attribute :sticky, (arg == true || arg.to_s == '1' ? 1 : 0)
  end

  def sticky? # spec_me cover_me heckle_me
    sticky == 1
  end

  def project # spec_me cover_me heckle_me
    board.project
  end

  def editable_by?(usr) # spec_me cover_me heckle_me
    usr && usr.logged? && (usr.allowed_to?(:edit_messages, project) || (self.author == usr && usr.allowed_to?(:edit_own_messages, project)))
  end

  def destroyable_by?(usr) # spec_me cover_me heckle_me
    usr && usr.logged? && (usr.allowed_to?(:delete_messages, project) || (self.author == usr && usr.allowed_to?(:delete_own_messages, project)))
  end

  # Returns the mail adresses of users that should be notified
  def recipients # spec_me cover_me heckle_me
    notified = project.notified_users
    notified << author if author && author.active? && !author.pref[:no_emails]
    notified.reject! {|user| !visible?(user) || user.pref[:no_emails]}
    notified.collect(&:mail)
  end

  private

  def add_author_as_watcher # cover_me heckle_me
    Watcher.create(:watchable => self.root, :user => author)
  end

end

