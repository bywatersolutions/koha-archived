[% USE AuthorisedValues %]
<script type="text/javascript">
//<![CDATA[
    var BROWSER_RETURN_TO_SEARCH = _("Return to results");
    var BROWSER_PREVIOUS = _("Previous");
    var BROWSER_NEXT = _("Next");

    var STRINGS = {
        "DebitTypes": {
            "FINE"                      : _("Fine"),
            "ACCOUNT_MANAGEMENT_FEE"    : _("Account management fee"),
            "SUNDRY"                    : _("Sundry"),
            "LOST"                      : _("Lost item"),
            "HOLD"                      : _("Hold fee"),
            "RENTAL"                    : _("Rental fee"),
            "NEW_CARD"                  : _("New card"),
            [% FOREACH a IN AuthorisedValues.Get('MANUAL_INV') %]
                "[% a.authorised_value %]" : "[% a.lib %]",
            [% END %]
        },

        "CreditTypes": {
            "CREDIT"                    : _("Credit"),
            "PAYMENT"                   : _("Payment"),
            "WRITEOFF"                  : _("Writeoff"),
            "FOUND"                     : _("Lost item found"),
            "FORGIVEN"                  : _("Forgiven"),
            [% FOREACH a IN AuthorisedValues.Get('MANUAL_CREDIT') %]
                "[% a.authorised_value %]" : "[% a.lib %]",
            [% END %]
        }
    }
//]]>
</script>
