defmodule SinglePipes do
  @moduledoc """
    Example module containing single and multiple pipelines.
    Intended as test to remove single pipes.
  """

  @required_fields ~w(amount_in_cents api_token ip service_id)a
  @optional_fields ~w(currency custom_data description)a

  @currency_ids %{
    KRW: 29, DKK: 7, LVL: 12, NOK: 20, USD: 2, GBP: 9, PHP: 32, SEK: 16, HUF: 10,
    CAD: 25, NZD: 31, LTL: 11, AUD: 24, JPY: 3, MYR: 30, SKK: 17, EEK: 8, BGN: 4,
    CNY: 26, TRY: 23, THB: 34, PLN: 14, EUR: 1, HRK: 21, IDR: 28, HKD: 27, CZK: 6,
    CHF: 18, MXN: 40, INR: 37, SGD: 33, RON: 15, ZAR: 35, RUB: 22, ISK: 19
  }

  def changeset(struct, params \\ %{}) do
    params = params |> add_defaults |> maybe_cast_payment_provider_to_string

    struct
    |> cast(params, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_inclusion(
      :currency,
      string_keys(@currency_ids),
      message: "should be one of #{Map.keys(@currency_ids) |> Enum.join(", ")}"
    )
    |> set_payment_provider_option
  end

  def create(params \\ %{})
  def create(params) when is_list(params), do: create(Enum.into(params, %{}))

  def create(params) do
    changeset = SinglePipes.changeset(%{}, params)

    if changeset.valid? do
      {:ok, changeset |> apply_changes()}
    else
      {:error, changeset.errors}
    end
  end

  def apply_changes(val), do: val

  defp string_keys(map), do: Enum.map(map, fn {k, _v} -> to_string(k) end)
end
