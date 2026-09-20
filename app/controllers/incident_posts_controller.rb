class IncidentPostsController < ApplicationController
  include SkipAuthorization

  before_action :set_incident
  before_action :set_post,   only: [:update, :destroy, :toggle_like]
  before_action :require_author, only: [:update, :destroy]

  # POST /incidents/:incident_id/incident_posts
  def create
    post = @incident.posts.new(post_params)
    post.user = current_user
    if post.save
      redirect_to incident_users_path(@incident, anchor: 'feed-composer-anchor'), notice: 'Posted.'
    else
      redirect_back fallback_location: incident_users_path(@incident),
                    alert: post.errors.full_messages.to_sentence
    end
  end

  # PATCH /incidents/:incident_id/incident_posts/:id
  def update
    if @post.update(post_params)
      redirect_back fallback_location: incident_users_path(@incident), notice: 'Post updated.'
    else
      redirect_back fallback_location: incident_users_path(@incident),
                    alert: @post.errors.full_messages.to_sentence
    end
  end

  # DELETE /incidents/:incident_id/incident_posts/:id
  def destroy
    @post.destroy
    redirect_back fallback_location: incident_users_path(@incident), notice: 'Post deleted.'
  end

  # POST /incidents/:incident_id/incident_posts/:id/toggle_like
  def toggle_like
    like = @post.likes.find_by(user_id: current_user.id)
    if like
      like.destroy
    else
      @post.likes.create(user: current_user)
    end
    redirect_back fallback_location: incident_users_path(@incident)
  end

  private

  def set_incident
    @incident = Incident.find(params[:incident_id])
  end

  def set_post
    @post = @incident.posts.find(params[:id])
  end

  def require_author
    return if @post.user_id == current_user&.id
    redirect_to incident_users_path(@incident), alert: "You can only edit or delete your own posts."
  end

  def post_params
    params.require(:incident_post).permit(:body, :parent_id)
  end
end
