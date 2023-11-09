
using UdonSharp;
using UnityEngine;
using VRC.SDKBase;
using VRC.Udon;
using UnityEngine;

public class ToggleEnlightenRTGI : UdonSharpBehaviour 
{
	public EmissionUpdate.EmissiveUpdater2 Updater;
	public bool defaultOn;
	private bool bNonGlobalToggle;
	
	void Start()
	{
		bNonGlobalToggle = defaultOn;

		Updater.SetEnabled( bNonGlobalToggle );
	}

	public override void Interact()
	{
		bNonGlobalToggle = !bNonGlobalToggle;
		
		Updater.SetEnabled( bNonGlobalToggle );
	}
}
