class Api::V1::ReservationsController < ApplicationController
  # new 9
  before_action :authenticate_with_token!
  before_action :set_reservation, only: [:approve, :decline]

  def create
    game = Game.find(params[:game_id])

    if current_user.stripe_id.blank?
      render json: {error: "Please update your payment method", is_success: false}, status: 404
    elsif current_user == game.user
      #Maybe we don't need this.
      render json: {error: "Unable to book a game you created", is_success: false}, status: 404
    else
      start_date = DateTime.parse(reservation_params[:start_date])

      days = 1

      special_days = Calendar.where(
        "game_id = ? AND status = ? and day BETWEEN ? and ? AND price <> ?",
        game.id, 0, start_date, start_date, game.price
      ).pluck(:price)

      reservation = current_user.reservations.build(reservation_params)
      reservation.game = game
      reservation.price = game.price
      reservation.total = game.price
      special_days.each do |d|
        reservation.total += d.price
      end

      if reservation.Waiting! && game.Instant?
        charge(game, reservation)
      end

      render json: {is_success: true}, status: :ok
    end
  end
  # new 11
  def reservations_by_game
    reservations = Reservation.where(game_id: params[:id])
    reservations = reservations.map { |r| ReservationSerializer.new(r, avatar_url: r.user.image)}

    render json: {reservations: reservations, is_success: true}, status: :ok

  end
  #new 14
  def approve
    if @reservation.game.user_id == current_user.id
      charge(@reservation.game, @reservation)
      render json: {is_success: true}, status: :ok
    else
      render json: {error: "No Permission", is_success: false}, status: 404
    end
  end

  def decline
    if @reservation.game.user_id == current_user.id
      @reservation.Declined!
      render json: {is_success: true}, status: :ok
    else
      render json: {error: "No Permission", is_success: false}, status: 404
    end
  end

  private

  def set_reservation
    @reservation = Reservation.find(params[:id])
  end

  def reservation_params
    params.require(:reservation).permit(:start_date)
  end

  def charge(game, reservation)
    if !reservation.user.stripe_id.blank? && !game.user.merchant_id.blank?
      customer = Stripe::Customer.retrieve(reservation.user.stripe_id)
      charge = Stripe::Charge.create(
        :customer => customer.id,
        :amount => reservation.total * 100,
        :description => game.listing_name,
        :currency => 'usd',
        :destination => {
          :amount => reservation.total * 95,
          :account => game.user.merchant_id
        }
      )

      if charge
        reservation.Approved!
      else
        reservation.Declined!
      end
    end

  rescue Stripe::CardError => e
    reservation.declined!
    render json: {error: e.message, is_success: false}, status: 404

  end
end
