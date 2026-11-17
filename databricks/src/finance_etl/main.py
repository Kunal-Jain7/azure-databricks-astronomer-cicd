import argparse


def get_args(argv=None):
    parser = argparse.ArgumentParser()
    parser.add_argument('--catalog', required=True)
    parser.add_argument('--schema', required=True)
    return parser.parse_args(argv)


def main():
    args = get_args()
    from pyspark.sql import SparkSession
    spark = SparkSession.builder.getOrCreate()
    print(f"Finance job started in {args.catalog}.{args.schema}")
    # spark.sparkContext is not available on serverless compute, so use spark.version.
    print(f"Spark version: {spark.version}")
    # Replace with actual transformations. No secrets printed here.


if __name__ == '__main__':
    main()
