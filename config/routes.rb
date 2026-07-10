Rails.application.routes.draw do
  resources :checkins
  resources :attachments
  resources :units
  resources :demobs
  resources :posts
  resources :blocks
  resources :covers
  resources :teams
  resources :safety_messages
  resources :commo_items
  resources :commo_plans
  resources :covers
  resources :activities
  resources :actions
  resources :incidents
  resources :resources
  resources :assignments
  resources :objectives, only: [:create, :update, :destroy]
  resources :plans
  root to: 'home#index'

  devise_for :users, controllers: {
    # Override the following Devise controllers with our custom versions
    registrations: 'users/registrations'
  }

  namespace :admin do
    resources :users
  end

  resources :incidents do
    get 'invite', on: :collection
    resources :checkins do
      collection do
        patch :sort
      end
    end
    resources :posts
    resources :resources do
      resources :demobs
    end
    resources :requests, only: [:index] do
      resource :checkin, only: [:new, :create], controller: 'request_checkins'
    end
    resources :dump_imports, only: [:new, :create]
    resources :schedules, only: [:index, :create, :update, :destroy]
    resources :demob_notifications, only: [:index, :update, :destroy] do
      member { patch :transmit }
    end
    resources :plans do
      member do
        post :publish
        delete :unpublish
      end
      resources :assignments
      resources :commo_plans
      resources :safety_messages
      resources :covers
    end

    resource :board, only: [:show] do
      patch :move
    end

    resources :org_units, only: [:create, :destroy]
  end
 

  # form_for is easier to use with a resourceful route
  resources :contact_forms, only: [:create]
  # A non-resourceful route was used to place the contact form at /contact
  get 'contact' => 'contact_forms#new', as: 'contact'
  get 'incidents/:id/users'   => 'incidents#users', as: :incident_users
  get 'incidents/:id/perimeter' => 'incidents#perimeter', as: :incident_perimeter, defaults: { format: :json }
  get 'incidents/:id/irwin_data' => 'incidents#irwin_data', as: :incident_irwin_data, defaults: { format: :json }
  get 'incidents/:id/plans/:id/202'        => 'plans#incident_objectives'
  get 'incidents/:id/plans/:id/202-pdf'        => 'plans#objectives_to_pdf'
  get 'incidents/:id/plans/:id/203'        => 'plans#incident_organization'
  get 'incidents/:id/plans/:id/203-pdf'        => 'plans#organization_to_pdf'
  get 'incidents/:id/plans/:id/assignments/:id/assignment_to_pdf'        => 'assignments#assignment_to_pdf'
  get 'incidents/:id/plans/:id/commo_plans/:id/commo_plan_to_pdf'        => 'commo_plans#commo_plan_to_pdf'
  get 'incidents/:id/plans/:id/covers/:id/cover_to_pdf'      => 'covers#cover_to_pdf'
  get 'incidents/:id/plans/:id/safety_messages/:id/safety_message_to_pdf'  => 'safety_messages#safety_message_to_pdf'
  get 'confimation'   => 'checkins/confirmations'
  # get 'incidents/:id/invite', to: 'incidents#invite'
  post '/incidents/invite', to: 'incidents#invite'
  post '/incidents/remove-user', to: 'incidents#remove_user'

  # Invite-acceptance flow: token in URL, GET shows form, PATCH submits.
  get   '/invitations/:invitation_token/accept',
        to: 'invitations#edit',
        as: :accept_invitation
  patch '/invitations/:invitation_token/accept',
        to: 'invitations#update',
        as: :invitation

end
