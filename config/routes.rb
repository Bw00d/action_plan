Rails.application.routes.draw do
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
    resources :plans do
      resources :assignments
    end
  end
  # resources :plans do
  #   resources :assignments
  # end

  # form_for is easier to use with a resourceful route
  resources :contact_forms, only: [:create]
  # A non-resourceful route was used to place the contact form at /contact
  get 'contact' => 'contact_forms#new', as: 'contact'
  get 'incidents/:id/plans/:id/cover'      => 'plans#cover'
  get 'incidents/:id/plans/:id/202'        => 'plans#incident_objectives'
end
