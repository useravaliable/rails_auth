module Auth
  class UsersController < BaseController
    before_action :set_user, only: [:show]

    def index
      @users = User.page(params[:page])
    end

    def show
    end

    private
    def set_user
      @user = User.find(params[:id])
    end

  end
end
