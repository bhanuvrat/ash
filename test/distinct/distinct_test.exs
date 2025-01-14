defmodule Ash.Test.Sort.SortTest do
  @moduledoc false
  use ExUnit.Case, async: true

  require Ash.Query

  defmodule Post do
    @moduledoc false
    use Ash.Resource, data_layer: Ash.DataLayer.Ets

    ets do
      private?(true)
    end

    actions do
      defaults [:read, :create, :update]
    end

    attributes do
      uuid_primary_key :id
      attribute :title, :string
    end

    calculations do
      calculate :first_title_word, :string, expr(at(string_split(title, " ", trim?: true), 0))
    end
  end

  defmodule Api do
    @moduledoc false
    use Ash.Api

    resources do
      allow_unregistered? true
    end
  end

  setup do
    Post
    |> Ash.Changeset.for_create(:create, %{title: "fred armisen"})
    |> Api.create!()

    Post
    |> Ash.Changeset.for_create(:create, %{title: "fred armisen"})
    |> Api.create!()

    Post
    |> Ash.Changeset.for_create(:create, %{title: "fred weasley"})
    |> Api.create!()

    :ok
  end

  test "distinct by attribute works" do
    assert [_, _] = Post |> Ash.Query.distinct(:title) |> Api.read!()
  end

  test "distinct by calculation works" do
    assert [_] =
             Post
             |> Ash.Query.distinct(:first_title_word)
             |> Api.read!()
  end
end
