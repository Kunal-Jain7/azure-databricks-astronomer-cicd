from pathlib import Path

from airflow.dag_processing.dagbag import DagBag

DAGS = Path(__file__).resolve().parents[1] / "dags"


def _bag():
    return DagBag(dag_folder=str(DAGS), bundle_path=DAGS, bundle_name="dags")


def test_no_import_errors():
    assert _bag().import_errors == {}


def test_pipeline_dag_present():
    dag = _bag().dags.get("databricks_pipeline")
    assert dag is not None
    assert [t.task_id for t in dag.tasks] == ["run_finance_etl"]
