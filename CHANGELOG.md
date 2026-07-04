# Changelog

## 0.3.14

* Modbus TCP Client (active mode): handles multiple responses received in a single tcp packet.
* Modbus TCP Server: handles multiple requests received in a single tcp packet.
* Modbus TCP Client & Server: reassemble requests/responses split across tcp packets.

## 0.3.13

* Modbus TCP: the protocol identifier other than Modbus (0x00, 0x00) has been relaxed and logged.

## 0.3.12

* Improve bitstring logging.

## 0.3.11

* Elixir 1.15 (OTP 26) warnings fixed.
* Dependencies updated.
