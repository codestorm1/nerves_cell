defmodule NervesCell.CellStateMachine do
  @moduledoc """
  The main flow and state of the cellphone is here
  """
  use GenStateMachine, callback_mode: :state_functions

  require Logger
  alias FonaModem
  @phone_number_length 10

  # @ext_tone_dial_tone 2

  def start_link({state, data}) do
    Logger.info("[CellStateMachine Modem] start_link/1")
    GenStateMachine.start_link(__MODULE__, {state, data}, name: __MODULE__)
  end

  @impl GenStateMachine
  def init({state, data}) do
    Logger.info(
      "[CellStateMachine Modem] init.  pid: #{inspect(self())} init_state: #{inspect(state)} data: #{inspect(data)}"
    )

    {:ok, state, data}
  end

  # Client API
  #
  def go_off_hook() do
    Logger.info("calling #{__MODULE__} :go_off_hook")
    GenStateMachine.call(__MODULE__, :go_off_hook)
  end

  def go_on_hook() do
    Logger.info("calling #{__MODULE__} :go_on_hook")
    GenStateMachine.call(__MODULE__, :go_on_hook)
  end

  @spec digit_dialed(binary()) :: :ok
  def digit_dialed(digit) when is_binary(digit) do
    GenStateMachine.call(__MODULE__, {:digit_dialed, digit})
  end

  # Server Callbacks
  #

  # making_phone_call state
  #
  def making_phone_call({:call, from}, :go_on_hook, _data) do
    data = ""
    Logger.info("get digit -> hang up, data is #{data}")
    FonaModem.hang_up()
    {:next_state, :on_hook, data, [{:reply, from, data}]}
  end

  def making_phone_call({:call, from}, _action, _data) do
    {:keep_state_and_data, [{:reply, from, {:error, :invalid_state_transition}}]}
  end

  # off_hook_get_digit state
  #
  def off_hook_get_digit({:call, from}, {:digit_dialed, digit}, data) do
    data = data <> digit
    Logger.info("get digit -> got a digit, data is #{data}")
    result = FonaModem.play_tone(digit)
    Logger.info(result)

    if String.length(data) == @phone_number_length do
      Logger.info("Make phone call to #{data}")
      result = FonaModem.make_phone_call(data)
      Logger.info(result)

      {:next_state, :making_phone_call, data, [{:reply, from, :ok}]}
    else
      {:keep_state, data, [{:reply, from, :ok}]}
    end
  end

  def off_hook_get_digit({:call, from}, :go_on_hook, _data) do
    data = ""
    Logger.info("get digit -> hang up, data is #{data}")
    {:next_state, :on_hook, data, [{:reply, from, :ok}]}
  end

  def off_hook_get_digit({:call, from}, _action, _data) do
    {:keep_state_and_data, [{:reply, from, {:error, :invalid_state_transition}}]}
  end

  # off_hook_dialtone state
  #
  def off_hook_dialtone({:call, from}, {:digit_dialed, digit}, data) do
    data = data <> digit
    Logger.info("dialtone -> got a digit, data is #{data}")
    result = FonaModem.play_tone(digit)
    Logger.info(result)
    {:next_state, :off_hook_get_digit, data, [{:reply, from, :ok}]}
  end

  def off_hook_dialtone({:call, from}, :go_on_hook, data) do
    Logger.info("off hook hanging up")
    # FonaModem.cancel_ext_tone()
    {:next_state, :on_hook, data, [{:reply, from, :ok}]}
  end

  def off_hook_dialtone({:call, from}, _action, _data) do
    {:keep_state_and_data, [{:reply, from, {:error, :invalid_state_transition}}]}
  end

  # on_hook state
  #
  def on_hook({:call, from}, :go_off_hook, data) do
    Logger.info("on hook going off hook")
    # no ext tone
    # FonaModem.play_ext_tone(@ext_tone_dial_tone)
    {:next_state, :off_hook_dialtone, data, [{:reply, from, :ok}]}
  end

  def on_hook({:call, from}, _action, _data) do
    {:keep_state_and_data, [{:reply, from, {:error, :invalid_state_transition}}]}
  end
end
