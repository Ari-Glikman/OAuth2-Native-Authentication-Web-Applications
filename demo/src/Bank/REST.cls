Class Bank.REST Extends %CSP.REST
{

XData UrlMap
{
<Routes>
  <Route Url="/checkbalance" Method="GET" Call="CheckBalance"/>
  <Route Url="/transfer" Method="POST" Call="Transfer"/>
</Routes>
}

/// Returns true if the current process has the named IRIS role.
ClassMethod HasRole(role As %String) As %Boolean
{
    Quit ($Find(","_$ROLES_",", ","_role_",")>0)
}

/// Returns 1 if the request should stop (forbidden), 0 if allowed.
ClassMethod RequireRole(role As %String, scopeHint As %String = "") As %Boolean
{
    If ..HasRole(role) Quit 0

    Set %response.Status = 403
    If scopeHint'="" {
        Do ..WriteJSONError("Missing scope: "_scopeHint)
    } Else {
        Do ..WriteJSONError("Forbidden")
    }

    Quit 1
}

ClassMethod MyAccount() As %String
{
    If $USERNAME="user1" Quit "ACCT-1"
    If $USERNAME="user2" Quit "ACCT-2"
    Quit ""
}

ClassMethod CheckBalance() As %Status
{
    If ..RequireRole("BankBalanceRead","bank.balance.read") Quit $$$OK

    Set fromAcct = ..MyAccount()
    If fromAcct="" {
        Set %response.Status = 403
        Do ..WriteJSONError("No account mapped for user")
        Quit $$$OK
    }

    &sql(SELECT Balance INTO :bal FROM BankAccount WHERE AccountId=:fromAcct)
    If SQLCODE=100 {
        Set %response.Status = 404
        Do ..WriteJSONError("Account not found")
        Quit $$$OK
    }
    If SQLCODE'=0 {
        Set %response.Status = 500
        Do ..WriteJSONError("sql select failed")
        Quit $$$OK
    }

    Set %response.ContentType = "application/json"
    Set rsp = ##class(%DynamicObject).%New()
    Set rsp.dollars = bal
    Do rsp.%ToJSON()
    Quit $$$OK
}

ClassMethod Transfer() As %Status
{
    If ..RequireRole("BankTransferWrite","bank.transfer.write") Quit $$$OK

    Set sc = $$$OK

    Set fromAcct = ..MyAccount()
    If fromAcct="" {
        Set %response.Status = 403
        Do ..WriteJSONError("No account mapped for user")
        Quit sc
    }

    Set body = %request.Content.Read()

    Set invalidJSON = 0
    Try {
        Set obj = ##class(%DynamicObject).%FromJSON(body)
    } Catch ex {
        Set %response.Status = 400
        Do ..WriteJSONError("Invalid JSON body")
        Set invalidJSON = 1
    }
    If invalidJSON Quit sc

    Set toAcct = obj.toAccount
    If toAcct="" {
        Set %response.Status = 400
        Do ..WriteJSONError("Missing toAccount")
        Quit sc
    }

    Set amt = obj.dollars
    If amt'>0 {
        Set %response.Status = 400
        Do ..WriteJSONError("dollars must be > 0")
        Quit sc
    }

    If toAcct = fromAcct {
        Set %response.Status = 400
        Do ..WriteJSONError("toAccount must be different")
        Quit sc
    }

    TSTART

    &sql(SELECT Balance INTO :fromBal FROM BankAccount WHERE AccountId=:fromAcct)
    If SQLCODE'=0 {
        TROLLBACK
        Set %response.Status = 500
        Do ..WriteJSONError("sql select failed")
        Quit sc
    }

    If fromBal < amt {
        TROLLBACK
        Set %response.Status = 400
        Do ..WriteJSONError("Insufficient funds")
        Quit sc
    }

    &sql(UPDATE BankAccount SET Balance=Balance-:amt WHERE AccountId=:fromAcct)
    If SQLCODE'=0 {
        TROLLBACK
        Set %response.Status = 500
        Do ..WriteJSONError("sql debit failed")
        Quit sc
    }

    &sql(UPDATE BankAccount SET Balance=Balance+:amt WHERE AccountId=:toAcct)
    If SQLCODE'=0 {
        TROLLBACK
        Set %response.Status = 500
        Do ..WriteJSONError("sql credit failed")
        Quit sc
    }

    If %ROWCOUNT=0 {
        TROLLBACK
        Set %response.Status = 400
        Do ..WriteJSONError("toAccount not found")
        Quit sc
    }

    TCOMMIT

    Set %response.ContentType = "application/json"
    Set rsp = ##class(%DynamicObject).%New()
    Set rsp.ok = 1
    Do rsp.%ToJSON()
    Quit sc
}

ClassMethod WriteJSONError(msg As %String) As %Status
{
    Set %response.ContentType = "application/json"
    Set err = ##class(%DynamicObject).%New()
    Set err.error = msg
    Do err.%ToJSON()
    Quit $$$OK
}

}
