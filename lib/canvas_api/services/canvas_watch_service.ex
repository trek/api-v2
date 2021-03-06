defmodule CanvasAPI.CanvasWatchService do
  @moduledoc """
  A service for viewing and manipulating canvas watches.
  """

  use CanvasAPI.Web, :service

  alias CanvasAPI.{Account, Canvas, CanvasService, User, UserService,
                   CanvasWatch}

  @preload [:user, canvas: [:team]]

  @doc """
  Insert a new canvas watch.
  """
  @spec insert(attrs, Keyword.t) :: {:ok, CanvasWatch.t}
                                  | {:error, Changeset.t}
  def insert(attrs, opts) do
    %CanvasWatch{}
    |> CanvasWatch.changeset(attrs)
    |> put_canvas(attrs["canvas_id"], opts[:account])
    |> put_user(opts[:account])
    |> Repo.insert
  end

  @spec put_canvas(Changeset.t, String.t | nil, Account.t) :: Changeset.t
  defp put_canvas(changeset, id, account) when is_binary(id) do
    id
    |> CanvasService.get(account: account)
    |> case do
      {:ok, canvas} ->
        put_assoc(changeset, :canvas, canvas)
      {:error, _} ->
        add_error(changeset, :canvas, "was not found")
    end
  end

  defp put_canvas(changeset, _, _),
    do: add_error(changeset, :canvas, "is required")

  @spec put_user(Changeset.t, Account.t) :: Changeset.t
  defp put_user(changeset, account) do
    with canvas = %Canvas{} <- get_field(changeset, :canvas) do
      {:ok, user} = UserService.find_by_team(account, team_id: canvas.team_id)
      put_assoc(changeset, :user, user)
    else
        _ -> changeset
    end
  end

  @doc """
  Get a canvas watch by ID.
  """
  @spec get(String.t, Keyword.t) :: {:ok, CanvasWatch.t}
                                  | {:error, :watch_not_found}
  def get(id, opts) do
    opts[:account]
    |> watch_query
    |> maybe_lock
    |> where(canvas_id: ^id)
    |> Repo.one
    |> case do
      watch = %CanvasWatch{} ->
        {:ok, watch}
      nil ->
        {:error, :watch_not_found}
    end
  end

  @doc """
  List canvas watches.
  """
  @spec list(Keyword.t) :: [CanvasWatch.t]
  def list(opts \\ []) do
    opts[:account]
    |> watch_query
    |> filter(canvas: opts[:canvas])
    |> filter(opts[:filter])
    |> Repo.all
  end

  @spec filter(Ecto.Query.t, Keyword.t | map | nil) :: Ecto.Query.t
  defp filter(query, filter) when is_map(filter) or is_list(filter) do
    filter
    |> Enum.reduce(query, &do_filter/2)
  end

  defp filter(query, _), do: query

  @spec do_filter({String.t | atom, any}, Ecto.Query.t) :: Ecto.Query.t
  defp do_filter({:canvas, canvas = %Canvas{}}, query),
    do: where(query, canvas_id: ^canvas.id)
  defp do_filter({"canvas.id", canvas_id}, query),
    do: where(query, canvas_id: ^canvas_id)
  defp do_filter(_, query),
    do: query

  @doc """
  Delete a canvas watch.
  """
  @spec delete(String.t, Keyword.t) :: {:ok, CanvasWatch.t}
                                     | {:error, :watch_not_found}
  def delete(id, opts) do
    Repo.transaction(fn ->
      with {:ok, watch} <- get(id, opts) do
        Repo.delete(watch)
      end
      |> case do
        {:ok, watch} -> watch
        {:error, error} -> Repo.rollback(error)
      end
    end)
  end

  @spec watch_query(Account.t | nil) :: Ecto.Query.t
  defp watch_query(nil), do: CanvasWatch |> preload(^@preload)

  defp watch_query(account) do
    CanvasWatch
    |> join(:left, [w], u in User, w.user_id == u.id)
    |> where([_, u], u.account_id == ^account.id)
    |> preload(^@preload)
  end
end
