defmodule FileProcessor.ExecutionsTest do
  use FileProcessor.DataCase

  alias FileProcessor.Executions
  alias FileProcessor.Executions.Execution

  import FileProcessor.ExecutionsFixtures

  @valid_attrs %{
    files:      "ventas.csv",
    mode:       "sequential",
    result:     "• Estado: éxito",
    status:     "success",
    timestamp:  ~U[2026-02-14 06:39:00Z],
    total_time: 42
  }

  @invalid_attrs %{
    timestamp:  nil,
    mode:       nil,
    result:     nil,
    files:      nil,
    total_time: nil
  }

  # ---------------------------------------------------------------------------
  # CRUD básico
  # ---------------------------------------------------------------------------

  describe "list_executions/0" do
    test "devuelve todas las ejecuciones ordenadas por timestamp desc" do
      e1 = execution_fixture(%{timestamp: ~U[2026-02-14 06:00:00Z]})
      e2 = execution_fixture(%{timestamp: ~U[2026-02-15 06:00:00Z]})

      result = Executions.list_executions()
      assert length(result) == 2
      assert hd(result).id == e2.id
      assert List.last(result).id == e1.id
    end

    test "devuelve lista vacía si no hay ejecuciones" do
      assert Executions.list_executions() == []
    end
  end

  describe "get_execution!/1" do
    test "devuelve la ejecución con el id dado" do
      execution = execution_fixture()
      assert Executions.get_execution!(execution.id) == execution
    end

    test "lanza error si el id no existe" do
      assert_raise Ecto.NoResultsError, fn ->
        Executions.get_execution!(0)
      end
    end
  end

  describe "create_execution/1" do
    test "crea ejecución con datos válidos" do
      assert {:ok, %Execution{} = execution} = Executions.create_execution(@valid_attrs)
      assert execution.files      == "ventas.csv"
      assert execution.mode       == "sequential"
      assert execution.result     == "• Estado: éxito"
      assert execution.status     == "success"
      assert execution.total_time == 42
    end

    test "devuelve error con datos inválidos" do
      assert {:error, %Ecto.Changeset{}} = Executions.create_execution(@invalid_attrs)
    end
  end

  describe "update_execution/2" do
    test "actualiza ejecución con datos válidos" do
      execution   = execution_fixture()
      update_attrs = %{mode: "parallel", total_time: 99, status: "partial"}

      assert {:ok, %Execution{} = updated} = Executions.update_execution(execution, update_attrs)
      assert updated.mode       == "parallel"
      assert updated.total_time == 99
      assert updated.status     == "partial"
    end

    test "devuelve error con datos inválidos" do
      execution = execution_fixture()
      assert {:error, %Ecto.Changeset{}} = Executions.update_execution(execution, @invalid_attrs)
      assert execution == Executions.get_execution!(execution.id)
    end
  end

  describe "delete_execution/1" do
    test "elimina la ejecución" do
      execution = execution_fixture()
      assert {:ok, %Execution{}} = Executions.delete_execution(execution)

      assert_raise Ecto.NoResultsError, fn ->
        Executions.get_execution!(execution.id)
      end
    end
  end

  describe "delete_all_executions/0" do
    test "elimina todas las ejecuciones" do
      execution_fixture()
      execution_fixture()
      Executions.delete_all_executions()
      assert Executions.list_executions() == []
    end
  end

  describe "change_execution/1" do
    test "devuelve un changeset" do
      execution = execution_fixture()
      assert %Ecto.Changeset{} = Executions.change_execution(execution)
    end
  end

  # ---------------------------------------------------------------------------
  # Filtros
  # ---------------------------------------------------------------------------

  describe "list_executions_filtered/1" do
    test "filtra por modo sequential" do
      seq = execution_fixture(%{mode: "sequential"})
      _par = execution_fixture_parallel()

      result = Executions.list_executions_filtered(mode: "sequential")
      assert length(result) == 1
      assert hd(result).id == seq.id
    end

    test "filtra por modo parallel" do
      _seq = execution_fixture()
      par  = execution_fixture_parallel()

      result = Executions.list_executions_filtered(mode: "parallel")
      assert length(result) == 1
      assert hd(result).id == par.id
    end

    test "filtra por modo benchmark" do
      _seq  = execution_fixture()
      bench = execution_fixture_benchmark()

      result = Executions.list_executions_filtered(mode: "benchmark")
      assert length(result) == 1
      assert hd(result).id == bench.id
    end

    test "filtra por rango de fechas" do
      _old    = execution_fixture(%{timestamp: ~U[2026-01-01 00:00:00Z]})
      recent  = execution_fixture(%{timestamp: ~U[2026-03-10 12:00:00Z]})

      result = Executions.list_executions_filtered(
        date_start: ~U[2026-03-01 00:00:00Z],
        date_end:   ~U[2026-03-31 23:59:59Z]
      )

      assert length(result) == 1
      assert hd(result).id == recent.id
    end

    test "combina filtro de modo y fecha" do
      _seq_old  = execution_fixture(%{mode: "sequential", timestamp: ~U[2026-01-01 00:00:00Z]})
      _par_new  = execution_fixture(%{mode: "parallel",   timestamp: ~U[2026-03-10 12:00:00Z]})
      seq_new   = execution_fixture(%{mode: "sequential", timestamp: ~U[2026-03-10 12:00:00Z]})

      result = Executions.list_executions_filtered(
        mode:       "sequential",
        date_start: ~U[2026-03-01 00:00:00Z],
        date_end:   ~U[2026-03-31 23:59:59Z]
      )

      assert length(result) == 1
      assert hd(result).id == seq_new.id
    end

    test "devuelve lista vacía si no hay coincidencias" do
      execution_fixture(%{mode: "sequential"})

      result = Executions.list_executions_filtered(mode: "benchmark")
      assert result == []
    end

    test "ignora filtros desconocidos sin crashear" do
      execution_fixture()
      result = Executions.list_executions_filtered(foo: "bar")
      assert length(result) == 1
    end
  end

  # ---------------------------------------------------------------------------
  # Estadísticas
  # ---------------------------------------------------------------------------

  describe "get_statistics/0" do
    test "devuelve ceros cuando no hay ejecuciones" do
      stats = Executions.get_statistics()
      assert stats.total      == 0
      assert stats.sequential == 0
      assert stats.parallel   == 0
      assert stats.benchmark  == 0
      assert stats.avg_time   == 0
    end

    test "cuenta correctamente por modo" do
      execution_fixture(%{mode: "sequential"})
      execution_fixture(%{mode: "sequential"})
      execution_fixture_parallel()
      execution_fixture_benchmark()

      stats = Executions.get_statistics()
      assert stats.total      == 4
      assert stats.sequential == 2
      assert stats.parallel   == 1
      assert stats.benchmark  == 1
    end

    test "calcula el promedio de tiempo correctamente" do
      execution_fixture(%{total_time: 100})
      execution_fixture(%{total_time: 200})

      stats = Executions.get_statistics()
      assert stats.avg_time == 150
    end

    test "avg_time es 0 cuando no hay ejecuciones" do
      assert Executions.get_statistics().avg_time == 0
    end
  end
end
