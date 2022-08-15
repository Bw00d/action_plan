Rails.application.routes.draw do
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
    resources :posts
    resources :resources
    resources :plans do
      resources :assignments
      resources :commo_plans
      resources :safety_messages
      resources :covers
    end
  end
 

  # form_for is easier to use with a resourceful route
  resources :contact_forms, only: [:create]
  # A non-resourceful route was used to place the contact form at /contact
  get 'contact' => 'contact_forms#new', as: 'contact'
  get 'incidents/:id/plans/:id/cover'      => 'plans#cover'
  get 'incidents/:id/plans/:id/cover-pdf'      => 'plans#cover_to_pdf'
  get 'incidents/:id/plans/:id/202'        => 'plans#incident_objectives'
  get 'incidents/:id/plans/:id/202-pdf'        => 'plans#objectives_to_pdf'
  get 'incidents/:id/plans/:id/203'        => 'plans#incident_organization'
  get 'incidents/:id/plans/:id/203-pdf'        => 'plans#organization_to_pdf'
  get 'incidents/:id/plans/:id/assignments/:id/assignment_to_pdf'        => 'assignments#assignment_to_pdf'
end
