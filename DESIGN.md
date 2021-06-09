v2
--

* bytes granularity (as opposed to lines granularity)


on_bytes(...)

... contains the the modified range

1. Modify in untangled code

untangled: [elem]
elem: char | sentinel

lines: [pointer to sentinels]

      lines
      ┌─────────────┐    ┌───────────────────────────────────┐
      │    o─────────────│─────────┐                         │
      │─────────────│    │         │                         │
      │    o─────────────┘         ▼                         ▼
      │─────────────│        ┌───┌───┌───┌────┌────┌───┌───┌───┌───┌───┌───┐
      │             │        │ A │#S │ H │ E  │ L  │ L │ O │#S │ H │ A │ A │
      │─────────────│        └───└───└───└────└────└───└───└───└───└───└───┘
      │             │          untangled, linked list
      └─────────────┘







