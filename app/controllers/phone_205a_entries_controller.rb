class Phone205aEntriesController < ApplicationController
  # Access is already gated by the authenticated user's incident
  # membership (set_incident loads from Incident regardless, same as
  # ResourcesController) — follow the same pattern of skipping Pundit's
  # verify_* callbacks here instead of writing a one-off policy.
  include SkipAuthorization

  before_action :set_incident
  before_action :set_entry, only: [:update, :destroy]

  # GET /incidents/:incident_id/phone_205a
  def index
    # Pick the latest plan so the shared plan tabrow has somewhere to
    # link back to. Nil-safe — the view renders a lite tabrow when
    # there's no plan yet.
    @plan = @incident.plans.order(:id).last
    @entries_by_section = @incident.phone_205a_entries
                                   .order(:section, :sort_order, :name)
                                   .group_by(&:section)
    @entry = @incident.phone_205a_entries.new  # for the "add" form
  end

  # POST /incidents/:incident_id/phone_205a
  def create
    @entry = @incident.phone_205a_entries.new(entry_params)
    if @entry.save
      redirect_to incident_phone_205a_entries_path(@incident),
                  notice: "Added #{@entry.name}."
    else
      # Friendly flash — tell the user what to fix without crashing the
      # page. Falls back to a general hint if the model errors list is
      # empty (e.g. nothing was submitted at all).
      msg = @entry.errors.full_messages.to_sentence.presence ||
            "Fill out at least a name and pick a section."
      redirect_to incident_phone_205a_entries_path(@incident), alert: msg
    end
  end

  # PATCH /incidents/:incident_id/phone_205a/:id — best_in_place inline edits.
  def update
    respond_to do |format|
      if @entry.update(entry_params)
        format.html { redirect_back fallback_location: incident_phone_205a_entries_path(@incident) }
        format.json { respond_with_bip(@entry) }
      else
        format.html { redirect_back fallback_location: incident_phone_205a_entries_path(@incident),
                                    alert: @entry.errors.full_messages.to_sentence }
        format.json { respond_with_bip(@entry) }
      end
    end
  end

  # DELETE /incidents/:incident_id/phone_205a/:id
  def destroy
    @entry.destroy
    redirect_to incident_phone_205a_entries_path(@incident)
  end

  # PATCH /incidents/:incident_id/phone_205a/sort
  # Body: { section: 'Command', ordered_ids: [12, 7, 15, ...] }
  # Fires on drag-drop within a section card. Rewrites sort_order on
  # exactly the rows being reshuffled; untouched sections are left alone.
  def sort
    section     = params[:section].to_s
    ordered_ids = Array(params[:ordered_ids]).map(&:to_i)
    entries = @incident.phone_205a_entries
                       .where(section: section, id: ordered_ids)
                       .index_by(&:id)
    ordered_ids.each_with_index do |id, idx|
      entries[id]&.update_column(:sort_order, idx)
    end
    head :ok
  end

  private

  def set_incident
    @incident = Incident.find(params[:incident_id])
  end

  def set_entry
    @entry = @incident.phone_205a_entries.find(params[:id])
  end

  # Key is :phone205a_entry (no underscore before "205a") — that's
  # Rails' default param_key inflection for Phone205aEntry, and it's
  # what both form_with and best_in_place generate. Matching the
  # default keeps every write path (add form + inline edits) talking
  # the same language.
  #
  # .fetch(..., {}) instead of .require — if the form posted with
  # nothing under the key, we want a validation failure that the user
  # sees as a friendly flash, not a 400 error page.
  def entry_params
    params.fetch(:phone205a_entry, {}).permit(:name, :position, :phone_number, :section)
  end
end
