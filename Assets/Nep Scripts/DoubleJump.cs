
using UdonSharp;
using UnityEngine;
using VRC.SDKBase;
using VRC.Udon;

public class DoubleJump : UdonSharpBehaviour
{
  public int numberOfExtraJumps = 1;
  public int numberOfExtraJumpsMochie = 2;
  public AudioSource doubleJumpSound;
  public float doubleJumpVerticalVelocity = 4;
  public float doubleJumpVerticalMochie = 10;
  public float doubleJumpHorizontalVelocity = 4;
  public float doubleJumpHorizontalMochie = 7;
  public float normalJumpVelocity = 3;

  public Vector3 feetSpherecastPos = new Vector3(0f, 0.3f, 0f);
  public float feetSpherecastRadius = 0.25f;
  public float feetSpherecastDist = 0.2f;
  public LayerMask collisionLayerMask = -4191999;
  public string[] whitelist = new string[2] { "Mochie", "Neр" };
  private RaycastHit hitInfo;
  private float playerXAxis;
  private float playerZAxis;
  private int jumps;

  private void Update()
  {
		if( Networking.LocalPlayer != null )
		{
			if (Networking.LocalPlayer.IsPlayerGrounded())
			{
			  jumps = numberOfExtraJumps;
			}
		}
  }

  private void Start()
  {
   /* string name = Networking.LocalPlayer.displayName;
    foreach (string plrName in whitelist)
    {
      if (name == plrName)
      {
        doubleJumpVerticalVelocity = doubleJumpVerticalMochie;
        doubleJumpHorizontalVelocity = doubleJumpHorizontalMochie;
        numberOfExtraJumps = numberOfExtraJumpsMochie;
        break;
      }
    } */
  }

  void InputMoveHorizontal(float axisVal, VRC.Udon.Common.UdonInputEventArgs args)
  {
    playerXAxis = axisVal;
  }

  void InputMoveVertical(float axisVal, VRC.Udon.Common.UdonInputEventArgs args)
  {
    playerZAxis = axisVal;
  }

  void InputJump(bool pressed, VRC.Udon.Common.UdonInputEventArgs args)
  {
    if (pressed)
    {
      if (!Networking.LocalPlayer.IsPlayerGrounded())
      {
        Vector3 sphereCastPos = Networking.LocalPlayer.GetPosition() + feetSpherecastPos;
        float sphereCastDist = -(Networking.LocalPlayer.GetVelocity().y)*Time.deltaTime;
        //If the player is still on the ground, but because of VRC's lame ass grounding detection it thinks the player is in the air
        if (Physics.SphereCast(sphereCastPos, feetSpherecastRadius, Vector3.down, out hitInfo, feetSpherecastDist + sphereCastDist, collisionLayerMask))
        {
          Vector3 playerVelocity = Networking.LocalPlayer.GetVelocity();
          playerVelocity.y = normalJumpVelocity;
          Networking.LocalPlayer.SetVelocity(playerVelocity);
          jumps = numberOfExtraJumps;
        }
        // Actual double jump
        else if (jumps > 0)
        {
          Vector3 playerForward = Networking.LocalPlayer.GetRotation() * Vector3.forward;
          Vector2 playerZVelocity = (new Vector2(playerForward.x, playerForward.z));
          playerZVelocity.Normalize();
          Vector2 playerXVelocity = new Vector2(playerZVelocity.y, -playerZVelocity.x);

			    Vector2 playerHorizVelocity = doubleJumpHorizontalVelocity * (playerXAxis * playerXVelocity + playerZAxis * playerZVelocity);
			    Networking.LocalPlayer.SetVelocity(new Vector3(playerHorizVelocity.x, doubleJumpVerticalVelocity, playerHorizVelocity.y));

          doubleJumpSound.transform.position = sphereCastPos;
          doubleJumpSound.Play();
          jumps--;
        }
      }
    }
  }


}
