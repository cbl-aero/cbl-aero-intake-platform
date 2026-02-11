import time


def main() -> None:
    while True:
        print("worker running...")
        time.sleep(10)


if __name__ == "__main__":
    main()
