class PostsController < ApplicationController
  before_filter :member_only, :except => [:show, :index]
  after_filter :save_recent_tags, :only => [:update]
  respond_to :html, :xml, :json
  
  def index
    @post_set = PostSet.new(params[:tags], params[:page], params[:before_id])
    respond_with(@post_set)
  end
  
  def show
    @post = Post.find(params[:id])
    respond_with(@post)
  end
  
  def update
    @post = Post.find(params[:id])
    @post.update_attributes(params[:post])
    respond_with(@post)
  end
  
  def revert
    @post = Post.find(params[:id])
    @version = PostVersion.find(params[:version_id])
    @post.revert_to!(@version)
    respond_width(@post)
  end

private
  def save_recent_tags
    if params[:tags] || (params[:post] && params[:post][:tags])
      tags = Tag.scan_tags(params[:tags] || params[:post][:tags])
      tags = TagAlias.to_aliased(tags) + Tag.scan_tags(session[:recent_tags])
      session[:recent_tags] = tags.uniq.slice(0, 40).join(" ")
    end
  end
end