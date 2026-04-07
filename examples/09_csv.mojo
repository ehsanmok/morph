"""Example 09: CSV serialization and deserialization.

Demonstrates: to_csv(), from_csv(), csv_header(), to_csv_row(),
handling of quoted fields with special characters.
"""

from morph.csv import csv_header, to_csv_row, to_csv, from_csv
from std.collections import List


@fieldwise_init
struct Employee(Defaultable, Movable, Copyable):
    var name: String
    var department: String
    var salary: Int
    var active: Bool

    def __init__(out self):
        self.name = ""
        self.department = ""
        self.salary = 0
        self.active = False


def main() raises:
    print("=== CSV Header ===\n")
    print(csv_header[Employee]())

    print("\n=== Single Row ===\n")

    var alice = Employee(
        name="Alice", department="Engineering", salary=120000, active=True
    )
    print(to_csv_row(alice))

    print("\n=== Full CSV (header + row) ===\n")

    print(to_csv(alice))

    print("\n=== Quoted Fields ===\n")

    var bob = Employee(
        name='Bob "The Builder"',
        department="R&D, Innovation",
        salary=95000,
        active=True,
    )
    print("With special chars:")
    print(to_csv(bob))

    print("\n=== Multi-Row CSV ===\n")

    var csv_str = String(
        "name,department,salary,active\n"
        "Alice,Engineering,120000,true\n"
        "Bob,Marketing,90000,false\n"
        "Carol,Engineering,115000,true"
    )
    print("Input CSV:")
    print(csv_str)

    print("\nParsed:")
    var employees = from_csv[Employee](csv_str)
    for i in range(len(employees)):
        var e = employees[i].copy()
        print(
            "  "
            + e.name
            + " | "
            + e.department
            + " | $"
            + String(e.salary)
            + " | active="
            + String(e.active)
        )

    print("\n=== Round-Trip ===\n")

    var original = Employee(
        name="Dave", department="Sales", salary=80000, active=False
    )
    var csv = to_csv(original)
    var restored = from_csv[Employee](csv)
    print("Original: " + original.name + " $" + String(original.salary))
    print("CSV:\n" + csv)
    print(
        "Restored: "
        + restored[0].name
        + " $"
        + String(restored[0].salary)
    )
    print(
        "Match: "
        + String(
            original.name == restored[0].name
            and original.salary == restored[0].salary
        )
    )
