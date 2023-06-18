defmodule Ash.Resource.Change do
  @moduledoc """
  The behaviour for an action-specific resource change.

  `c:init/1` is defined automatically by `use Ash.Resource.Change`, but can be implemented if you want to validate/transform any
  options passed to the module.

  The main function is `c:change/3`. It takes the changeset, any options that were provided
  when this change was configured on a resource, and the context, which currently only has
  the actor.
  """
  defstruct [:change, :on, :only_when_valid?, :description, where: []]

  @type t :: %__MODULE__{}
  @type ref :: {module(), Keyword.t()} | module()

  @doc false
  def schema do
    [
      on: [
        type: {:custom, __MODULE__, :on, []},
        default: [:create, :update],
        doc: """
        The action types the validation should run on. Destroy actions are omitted by default as most changes don't make sense for a destroy.
        """
      ],
      only_when_valid?: [
        type: :boolean,
        default: false,
        doc: """
        If the change should only be run on valid changes. By default, all changes are run unless stated otherwise here.
        """
      ],
      description: [
        type: :string,
        doc: "An optional description for the change"
      ],
      change: [
        type:
          {:spark_function_behaviour, Ash.Resource.Change, Ash.Resource.Change.Builtins,
           {Ash.Resource.Change.Function, 2}},
        doc: """
        The module and options for a change.
        Also accepts a function that takes the changeset and the context.

        See `Ash.Resource.Change.Builtins` for more.
        """,
        required: true
      ],
      where: [
        type:
          {:list,
           {:spark_function_behaviour, Ash.Resource.Validation, Ash.Resource.Validation.Builtins,
            {Ash.Resource.Validation.Function, 1}}},
        required: false,
        default: [],
        doc: """
        Validations that should pass in order for this validation to apply.
        These validations failing will not invalidate the changes, but instead just result in this change being ignored.
        Also accepts functions take the changeset.
        """
      ]
    ]
  end

  def atomic_schema do
    schema()
    |> Keyword.take([:description, :where])
    |> Keyword.put(:attribute, type: :atom, required: true, doc: "The attribute to update")
    |> Keyword.put(:expr,
      type: :any,
      required: true,
      doc: """
      The expression to use to update the attribute
      """
    )
  end

  def transform_atomic(atomic) do
    %{
      atomic
      | change: {Ash.Resource.Change.Atomic, attribute: atomic.attribute, expr: atomic.expr}
    }
  end

  @doc false
  def action_schema do
    Keyword.delete(schema(), :on)
  end

  @doc false
  def change({module, opts}) when is_atom(module) do
    if Keyword.keyword?(opts) do
      {:ok, {module, opts}}
    else
      {:error, "Expected opts to be a keyword, got: #{inspect(opts)}"}
    end
  end

  def change(module) when is_atom(module), do: {:ok, {module, []}}

  def change(other) do
    {:error, "Expected a module and opts, got: #{inspect(other)}"}
  end

  @doc false
  def on(list) do
    list
    |> List.wrap()
    |> Enum.all?(&(&1 in [:create, :update, :destroy]))
    |> case do
      true ->
        {:ok, List.wrap(list)}

      false ->
        {:error, "Expected items of [:create, :update, :destroy], got: #{inspect(list)}"}
    end
  end

  @type context :: %{
          optional(:actor) => Ash.Resource.record(),
          optional(any) => any
        }

  @callback init(Keyword.t()) :: {:ok, Keyword.t()} | {:error, term}
  @callback change(Ash.Changeset.t(), Keyword.t(), context) :: Ash.Changeset.t()
  @doc """
  An atomic expression of the provided change.

  To create an atomic, use the `Ash.Atomic.atomic/2` macro, which is automatically required
  when calling `use Ash.Resource.Change`.

  For example:

  ```elixir
  def atomic(opts, _context) do
    Ash.Atomic.atomic(:attribute_name, attribute_name + 42)
  end
  ```

  Return values:

  - `:not_atomic`: This change cannot be run atomically. The normal change behavior is skipped and the atomic is used.
  - `:ignore`: This change is not necessary in an atomic action. The normal change behavior is skipped and the atomic is not used.
  - `:safe`: This change's `change` function is safe to do atomically. For example, `set_attribute(:foo, 10)` has no need to be atomic.
  - `{:error, error}`: An error is added to the changeset (preventing the action).
  - `{:ok, atomic_or_list_of_atomics}`: The provided atomics are added to the changeset using `Ash.Changeset.atomic/2`.
  """
  @type after_atomic ::
          (Ash.Resource.record() -> {:ok, Ash.Resource.record()} | {:error, Ash.Error.t()})

  @callback atomic(Keyword.t(), context) ::
              :not_atomic
              | :ignore
              | :safe
              | {:ok, Ash.Atomic.t() | [Ash.Atomic.t()], after_atomic() | list(after_atomic())}
              | {:error, Ash.Error.t()}

  @doc """
  Replaces `change/3` for batch actions, allowing to optimize changes for bulk actions.
  """
  @callback batch_change([Ash.Changeset.t()], Keyword.t(), context) ::
              Enumerable.t(Ash.Changeset.t() | Ash.Notifier.Notification.t())

  @doc """
  Runs on each batch before it is dispatched to the data layer.
  """
  @callback before_batch([Ash.Changeset.t()], Keyword.t(), context) ::
              Enumerable.t(Ash.Changeset.t() | Ash.Notifier.Notification.t())

  @doc """
  Runs on each batch result after it is dispatched to the data layer.
  """
  @callback after_batch(
              [{Ash.Changeset.t(), Ash.Resource.record()}],
              Keyword.t(),
              context
            ) ::
              Enumerable.t(
                {:ok, Ash.Resource.record()}
                | {:error, Ash.Error.t()}
                | Ash.Notifier.Notification.t()
              )

  @optional_callbacks before_batch: 3, after_batch: 3, batch_change: 3

  defmacro __using__(_) do
    quote do
      @behaviour Ash.Resource.Change
      require Ash.Atomic

      def init(opts), do: {:ok, opts}
      def atomic(_opts, _context), do: :not_atomic

      defoverridable init: 1, atomic: 2
    end
  end
end
