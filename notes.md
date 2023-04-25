# LNURLpay over Tor

## Setup used
* Raspiblitz on the dev branch (~v1.9.0rc3 - earlier versions should work)
* CLN / LND with incoming capacity on public channel(s)
* BTCPayServer v1.8.2 (an earlier version with LNaddress support should work)

## Steps to create the service
* Create user and log in
* Create Store
* Set up a Lightning Node
* Paste the string from the Raspiblitz terminal menu CONNECT -> BTCPAY-CLN / BTCPAY-LND
* Save and close
* Click the Lightning Address under PLUGINS
* Add Address (the part after the @ does not matter) eg:
    ```
    oniontip@192.168.3.175:23001
    ```
* Create a Tor Hidden Service for the BTCPay HTTP port in the Raspiblitz terminal with this command:
    ```
    config.scripts/tor.onion-service.sh btcpayhttp 80 23000
    ```
    Example output:
    ```
    # Hidden Service for btcpayhttp
    HiddenServiceDir /mnt/hdd/tor/btcpayhttp
    HiddenServiceVersion 3
    HiddenServicePort 80 127.0.0.1:23000

    Reloading Tor to activate the Hidden Service...

    The Tor Hidden Service address for btcpayhttp is:
    foj373kji26vs4ntlltxlizrqfzkd5kqc45jst5hc6ntwcrma5a5xxqd.onion
    use with the port: 80
    ```
## LN address over Tor
* With the username and onion address put together the is ready:
    ```
    oniontip@foj373kji26vs4ntlltxlizrqfzkd5kqc45jst5hc6ntwcrma5a5xxqd.onion
    ```
## LNURLpay code
* The URL to encode (as explained in https://github.com/andrerfneves/lightning-address/blob/master/README.md#tldr):
    ```
    http://hidden-service.onion/.well-known/lnurlp/username
    ```
    In this example:
    ```
    http://foj373kji26vs4ntlltxlizrqfzkd5kqc45jst5hc6ntwcrma5a5xxqd.onion/.well-known/lnurlp/oniontip
    ```
* Encode to base64 according to https://github.com/lnurl/luds/blob/luds/01.md.
Can use https://lnurl.fiatjaf.com/codec/

* Example result:
    ```
    lnurl1dp68gup69uhkvmm2xvmnx6m2dyervannx3h8gmrvw3uxc6t6wfckv7ntvs6kkutrxs6k5um5x45xxdnww3mkxundvy6kzdtc0pckgtn0de5k7m309emk2mrv944kummhdchkcmn4wfk8qtm0de5k7mn5d9cqd8tcnf
    ```

* To create a QR code in the Raspiblitz terminal use the command:
    ```
    qr lnurl1dp68gup69uhkvmm2xvmnx6m2dyervannx3h8gmrvw3uxc6t6wfckv7ntvs6kkutrxs6k5um5x45xxdnww3mkxundvy6kzdtc0pckgtn0de5k7m309emk2mrv944kummhdchkcmn4wfk8qtm0de5k7mn5d9cqd8tcnf
    ```

## Pay to the static LNURLpay code over onion

* https://t.me/lightningtipbot now
* Breez - in next release https://twitter.com/ubbabeck/status/1634580039286104064
* Zeus - WIP draft: https://github.com/ZeusLN/zeus/pull/1349/files
* Bitcoin Beach Wallet - feature request: https://github.com/GaloyMoney/galoy-mobile/issues/1441
* More to come