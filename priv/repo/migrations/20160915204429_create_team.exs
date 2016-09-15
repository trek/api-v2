defmodule CanvasAPI.Repo.Migrations.CreateTeam do
  use Ecto.Migration

  def change do
    create table(:teams, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :domain, :citext, null: false
      add :name, :citext, null: false
      add :slack_id, :citext, null: false
      add :inserted_at, :timestamptz, null: false
      add :updated_at, :timestamptz, null: false
    end
  end
end
