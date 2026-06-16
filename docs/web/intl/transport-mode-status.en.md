# Transport mode dot status (international)

**Region**: International cluster (e.g. `api.shrimpsend.com` / `ws.shrimpsend.com`)

When you open a device conversation in ShrimpSend, the **Transport** bar above the chat shows each path (HTTP LAN direct, WebRTC LAN direct, S3 cloud relay, etc.). A **small dot** next to each label reflects that path’s current reachability.

Tap the **?** icon next to the bar label, or hover a mode chip, for details.

## Dot colors

| Color | Meaning | Notes |
|-------|---------|-------|
| **Green** | Verified and available | Probing confirmed this path works |
| **Blue** | Reverse pull only (HTTP) | Peer can reach this device’s HTTP, but direct push from here failed — transfer may be asymmetric |
| **Amber** | Try anyway, not verified (HTTP) | Direct path not confirmed; you may still switch and attempt |
| **Primary / accent** | WebRTC not tested yet | No WebRTC probe yet (often skipped when LAN already works) — not necessarily unavailable |
| **Gray** | Unavailable | Path cannot be used right now (S3 not configured, WebRTC probe failed, etc.) |

## Reverse pull only

Some networks (NAT, firewall, different router tiers) are **one-way**: e.g. your phone can reach your PC, but your PC cannot open a direct HTTP connection to your phone. HTTP may show a **blue** dot: files can still move via **reverse pull** from the side that can reach this device.

## Refresh button

The **refresh** icon re-runs connection probing (connection diagnostic). While probing, the icon spins; **dot colors update when results arrive**. Dots do not indicate “probing in progress” — they usually keep the last result until updated.

## FAQ

**Why is WebRTC accent-colored instead of green?**  
WebRTC has not been probed yet. When HTTP already works, the client may skip WebRTC to save time. You can still switch to WebRTC and try.

**Why is HTTP amber but still clickable?**  
Amber means direct reachability is unverified, but the mode is **attemptable**. Sending after switching will try the path again.

**Are device-list avatar dots the same?**  
No. List dots show **overall device** status (online / checking / offline; the mobile app also uses blue for pull-only). Transport bar dots are **per path**.

## Related

- **Connection diagnostic**: step-by-step HTTP direct, signaling, reverse pull, WebRTC, and S3 checks.
- **Manual mode switch**: tap a transport chip to override auto selection.
