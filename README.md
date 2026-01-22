<h2><u><strong>OAuth2 as a native authentication type for web applications</strong></u></h2>
<p>OAuth (<strong>O</strong>pen <strong>Auth</strong>orization) 2.0 is a standard way to let one application call another application’s API <strong>without</strong> sharing a username and password. Instead of sending credentials on every request, the client sends an <strong>access token</strong> (typically in an <code>Authorization: Bearer ...</code> header).</p>
<p>OAuth2 focuses on <em>authorization</em> (what the client is allowed to do). If you also need user login and identity claims, OAuth2 is commonly paired with OpenID Connect (OIDC) — but in this article we’ll stay focused on OAuth2 access tokens and scopes.</p>
<p>If you want a quick refresher, this short video is a good overview: <a href="https://learning.intersystems.com/course/view.php?id=252" target="_blank">OAuth 2.0 An Overview</a>.</p>
<h3>The problem OAuth2 solves (with a simple IRIS example)</h3>
<p>Assume IRIS hosts a small REST API for a bank account <code>ACCT-1</code> under <code>/bank</code>:</p>
<p><strong>GET</strong><br><code>/bank/checkbalance</code></p>
<pre class="codeblock-container" idlang="3" lang="JSON" tabsize="4"><code class="language-json hljs">{
  <span class="hljs-attr">"dollars"</span>: <span class="hljs-number">5</span>
}</code></pre>
<p><strong>POST</strong><br><code>/bank/transfer</code></p>
<pre class="codeblock-container" idlang="3" lang="JSON" tabsize="4"><code class="language-json hljs">{
  <span class="hljs-attr">"toAccount"</span>: <span class="hljs-string">"ACCT-2"</span>,
  <span class="hljs-attr">"dollars"</span>: <span class="hljs-number">2</span>
}</code></pre>
<p>Now suppose you want to allow a third-party app to monitor your balance. It should be allowed to call <code>/checkbalance</code>, but it should <strong>not</strong> be allowed to call <code>/transfer</code>.</p>
<p>This is where OAuth2 fits well: instead of giving the third-party app your IRIS username/password, you grant it limited access via a token. That token can be:</p>
<ul>
<li><strong>Scoped</strong> (e.g., “read balance” but not “transfer funds”)</li>
<li><strong>Time-limited</strong> (tokens expire)</li>
<li><strong>Revocable</strong> (you can withdraw access later)</li>
</ul>
<h3>What’s new in IRIS</h3>
<p>Starting in <a href="https://docs.intersystems.com/irislatest/csp/docbook/DocBook.UI.Page.cls?KEY=GCRN_new20252#GCRN_new20252_speed" target="_blank">IRIS 2025.2</a>, OAuth2 can be selected as a native authentication method for Web Applications — so enabling an OAuth2-protected web app is no longer a “DIY” exercise.</p>
<p>Concretely, IRIS can validate an incoming access token for a CSP/Web Application request and then establish a user context (username + roles) based on that token, just like other authentication types do.</p>
<p>(For reference on the older, more manual approach, see @Daniel.Kutac’s excellent <a href="https://community.intersystems.com/post/intersystems-iris-open-authorization-framework-oauth-20-implementation-part-1" target="_blank">series of articles</a>.)</p>
<h3>The Characters</h3>
<p>OAuth has a few “characters”:</p>
<ul>
<li><strong>Resource Owner</strong> (the user/owner of the bank account)</li>
<li><strong>Client</strong> (the third-party app; in this demo we use Postman as the client)</li>
<li><strong>Authorization Server</strong> (Keycloak; authenticates the user &amp; authorizes the request, deciding what scopes the client can receive, and issues the token)</li>
<li><strong>Resource Server</strong> (IRIS; hosts <code>/bank</code>, validates the token, and enforces what the token is allowed to do). The third-party app never sees your IRIS password — it presents a token, and IRIS makes the allow/deny decision.</li>
</ul>
<h3>Step 0: Prerequisites (avoid issuer / hostname issues)</h3>
<p><strong>Note:</strong> This demo uses HTTP to keep setup simple. In production you should use HTTPS (and real certificates), otherwise tokens and sessions can be intercepted.</p>
<p>This Open Exchange demo runs multiple Docker containers. One important rule to remember is:</p>
<ul>
<li><strong><code>localhost</code> on your host is not the same as <code>localhost</code> inside a container.</strong></li>
</ul>
<p>OAuth token validation checks the token’s <strong>issuer</strong> claim (<code>iss</code>). If Keycloak issues a token with an issuer like <code>http://localhost:8080/...</code> but IRIS discovers/validates it using <code>http://keycloak:8080/...</code>, IRIS will reject the token because those issuers do not match.</p>
<p>To keep the issuer stable, this demo uses the hostname <strong><code>keycloak</code></strong> consistently from both the host and the containers.</p>
<p><strong>On Windows</strong>, edit: <em>C:\Windows\System32\drivers\etc\hosts</em> and add:</p>
<blockquote>
<p>127.0.0.1 keycloak</p></blockquote>
<p><strong>On Linux/Mac</strong>, edit <em>/etc/hosts</em> and add the same line (you’ll typically need sudo).</p>
<p>From this point on, use <strong>http://keycloak:8080</strong> (not <code>http://localhost:8080</code>) when configuring Postman and IRIS.</p>
<h3>Step 1: Configure the Authorization Server (Keycloak)</h3>
<p>For the demo, the Authorization Server is Keycloak and it is already prepared for this use case (realm, clients, users, scopes). No work is needed here.</p>
<p>You can access the Keycloak admin console at <a href="http://keycloak:8080/keycloak/admin/master/console/" target="_blank">http://keycloak:8080/keycloak/admin/master/console/</a> (username/password <code>admin/admin</code>).</p>
<p>Explaining Keycloak itself is not in the scope for this article, but if you would like to read more you can find the docs <a href="https://www.keycloak.org/" target="_blank">here</a>.</p>
<h3>Step 2: Tell IRIS who the Authorization Server is</h3>
<p>In the Management Portal, go to:</p>
<p><em>System Administration &gt; Security &gt; OAuth 2.0 &gt; Client</em></p>
<p>Click <em>Create Server Description</em>, set the Issuer URL (in the demo: <code>http://keycloak:8080/keycloak/realms/bank</code>), then click <em>Discover</em> and <em>Save</em>. IRIS will pull the endpoints and metadata it needs from the server (authorization endpoint, token endpoint, JWKS URI, etc.).</p>

<img width="827" height="294" alt="image" src="https://github.com/user-attachments/assets/84647408-de60-49d2-bc32-cae96a73b7ca" />

<img width="1129" height="1198" alt="image" src="https://github.com/user-attachments/assets/706ee564-557b-4f31-a2ff-fe2006a0a40a" />

<h3>Step 3: Configure IRIS as the Resource Server</h3>
<p>Next, create a Resource Server entry so IRIS can validate tokens and enforce permissions:</p>

<img width="633" height="170" alt="image" src="https://github.com/user-attachments/assets/ef699a85-0c2b-49b8-9ab6-0a91f8e466c2" />

<p>Click <em>Create Resource Server</em>:</p>

<img width="853" height="313" alt="image" src="https://github.com/user-attachments/assets/618afeaf-4c79-4d8d-be49-e2d5034f9fc5" />

<p>Fill in the details of your resource server, for example:</p>
<p>Name: IRIS Bank Resource Server</p>
<p>Server Definition:&nbsp;<code>http://keycloak:8080/keycloak/realms/bank</code></p>
<p>Audiences: bank-demo, bank-monitor</p>
<p><strong>What is “Audience”?</strong> The token’s audience (<code>aud</code>) is the “intended recipient” of the token. By configuring audiences here, you are telling IRIS to accept only tokens that were issued for this API (i.e., tokens whose <code>aud</code> matches one of these values).</p>
<p>Click save.</p>

<img width="710" height="746" alt="image" src="https://github.com/user-attachments/assets/b91e47bb-0fa9-4d8d-8497-f94588547216" />

<p>We will set the Authenticator class in the next step. Note that this is not strictly necessary; you could use the <a href="https://docs.intersystems.com/irislatest/csp/documatic/%25CSP.Documatic.cls?LIBRARY=%25SYS&amp;CLASSNAME=%25OAuth2.ResourceServer.SimpleAuthenticator" target="_blank">%OAuth2.ResourceServer.SimpleAuthenticator</a> in your own implementations and just fill in what token property should be attributed to the role and user. However, for the sake of completeness we will create a simple custom authenticator class.</p>
<h3>Step 4: Create your Authenticator Class</h3>
<p>What should be authenticated? We will create a simple class <code>Bank.Authenticator</code> that maps token claims/scopes into an IRIS username and IRIS roles.</p>
<p>This is the key step that lets IRIS enforce “read-only” vs “transfer” behavior:</p>
<ul>
<li>The token’s <strong>scopes</strong> become <strong>IRIS roles</strong>.</li>
<li>Your <strong>web application</strong> (and/or your REST endpoints) can require those roles.</li>
</ul>
<p>In other words, this is what makes <code>/checkbalance</code>&nbsp; succeed for a “monitor” token while <code>/transfer</code> returns <strong>403 Forbidden</strong> unless the token includes the transfer scope.</p>

<pre class="codeblock-container" idlang="0" lang="ObjectScript" tabsize="4"><code class="language-cls hljs cos"><span class="hljs-keyword">Class</span> Bank.Authenticator <span class="hljs-keyword">Extends</span> <span class="hljs-built_in">%OAuth</span>2.ResourceServer.Authenticator
{

<span class="hljs-keyword">ClassMethod</span> HasScope(scopeStr <span class="hljs-keyword">As</span> <span class="hljs-built_in">%String</span>, scope <span class="hljs-keyword">As</span> <span class="hljs-built_in">%String</span>) <span class="hljs-keyword">As</span> <span class="hljs-built_in">%Boolean</span>
{
    <span class="hljs-keyword">Quit</span> ((<span class="hljs-string">" "</span>_scopeStr_<span class="hljs-string">" "</span>) [ (<span class="hljs-string">" "</span>_scope_<span class="hljs-string">" "</span>))
}

Method Authenticate(claims <span class="hljs-keyword">As</span> <span class="hljs-built_in">%DynamicObject</span>, oidc <span class="hljs-keyword">As</span> <span class="hljs-built_in">%Boolean</span>, Output properties <span class="hljs-keyword">As</span> <span class="hljs-built_in">%String</span>) <span class="hljs-keyword">As</span> <span class="hljs-built_in">%Status</span>
{
    <span class="hljs-comment">// Map token -&gt; IRIS username</span>
    <span class="hljs-keyword">Set</span> properties(<span class="hljs-string">"Username"</span>) = claims.<span class="hljs-string">"preferred_username"</span>
    <span class="hljs-comment">// Map scopes -&gt; IRIS roles</span>
    <span class="hljs-keyword">Set</span> scopeStr = claims.scope
    <span class="hljs-keyword">Set</span> roles = <span class="hljs-string">""</span>
    <span class="hljs-keyword">If</span> <span class="hljs-built_in">..HasScope</span>(scopeStr,<span class="hljs-string">"bank.balance.read"</span>) {
        <span class="hljs-keyword">Set</span> roles = roles_<span class="hljs-string">",BankBalanceRead"</span>
    }
    <span class="hljs-keyword">If</span> <span class="hljs-built_in">..HasScope</span>(scopeStr,<span class="hljs-string">"bank.transfer.write"</span>) {
        <span class="hljs-keyword">Set</span> roles = roles_<span class="hljs-string">",BankTransferWrite"</span>
    }

    <span class="hljs-keyword">If</span> <span class="hljs-built_in">$Extract</span>(roles,<span class="hljs-number">1</span>)=<span class="hljs-string">","</span> <span class="hljs-keyword">Set</span> roles=<span class="hljs-built_in">$Extract</span>(roles,<span class="hljs-number">2</span>,*)
    
    <span class="hljs-keyword">Set</span> properties(<span class="hljs-string">"Roles"</span>) = roles_<span class="hljs-string">",%DB_USER"</span>
    <span class="hljs-keyword">Quit</span> <span class="hljs-built_in">$$$OK</span>
}

}
</code></pre>



<p>Once you compile the class you will be able to set your authenticator class in your resource server:</p>

<img width="596" height="84" alt="image" src="https://github.com/user-attachments/assets/f1e9dff1-1928-451f-8c63-eb1198504dc6" />

<p>Save your resource server.</p>
<h3>Step 5: Enable OAuth2 on the Web Application</h3>
<p>Before enabling OAuth2 for a web app, you must enable it at the System level:</p>
<p><em>System Administration &gt; Security &gt; System Security &gt; Authentication/Web Session Options</em></p>

<img width="1455" height="1077" alt="image" src="https://github.com/user-attachments/assets/6de36293-f22d-4bd8-b416-3167ddb537c1" />

<p>Finally, on your Web Application definition, select <strong>OAuth2</strong> as an allowed authentication method. The dispatch class will check that the client has the necessary roles.</p>

<img width="598" height="364" alt="image" src="https://github.com/user-attachments/assets/7d4b5be2-6e71-4e26-9115-301237743087" />

<h3>Step 6: Test it out</h3>
<p>At this point, requests to your application can be authorized based on the presented token — so you can allow read-only access to <code>/checkbalance</code>&nbsp;while denying access to <code>/transfer</code> using the OAuth2 framework.</p>
<p>Load the Postman collection and environment. There are two demo users/passwords to have in mind: <code>user1/123</code> and <code>user2/123</code>.</p>
<p>User 1 has account <code>ACCT-1</code>, User 2 has account <code>ACCT-2</code>.</p>

<img width="542" height="285" alt="image" src="https://github.com/user-attachments/assets/877cafd7-4fac-4db7-994c-81bdb99e0be1" />

<p>In Postman, on Authorization click <em>Get New Access Token</em>:</p>

<img width="1600" height="831" alt="image" src="https://github.com/user-attachments/assets/8731675b-6b44-46e1-9222-3e8f16aba3ff" />

<p>This brings up the login screen for our Authorization Server:</p>

<img width="1179" height="607" alt="image" src="https://github.com/user-attachments/assets/68224369-517e-47e4-ac80-edd2e4118828" />

<p>Log in with <code>user1/123</code>. Click proceed and then click <em>Use Token</em>.</p>

<img width="710" height="138" alt="image" src="https://github.com/user-attachments/assets/2083c912-0363-4743-a3eb-faa74aeb4eae" />

<p>Send your GET to <code>/checkbalance</code>&nbsp;and you should see it return 5 dollars:</p>

<img width="1600" height="643" alt="image" src="https://github.com/user-attachments/assets/1556f7a7-060a-4162-9ef6-f92aef65f667" />

<p>Clear cookies and try logging in with user 2 and you should see them have 0 dollars in their balance.</p>
<p>Now get a token for user 1 and try to transfer user 2 a couple dollars. It should fail with <strong>403 Forbidden</strong>&nbsp;as this “app” does not have the required scopes (it is only monitoring the bank account and should not be able to transfer money).</p>

<img width="1041" height="422" alt="image" src="https://github.com/user-attachments/assets/c1b23c5b-f27e-4699-947a-e16621b211c8" />

<p>Try again with requests 3 and 4 which simulate a client with full access and you should be able to both check your balance and transfer funds.</p>

<img width="1033" height="412" alt="image" src="https://github.com/user-attachments/assets/be5dbdab-ef5e-47a1-a01d-26ca43943846" />

<p>The new OAuth2 native authentication type ensures it is intuitive to keep your web applications safe, and after all, that's what the I in IRIS is all about.</p>
