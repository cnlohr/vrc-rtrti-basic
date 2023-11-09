
using UdonSharp;
using UnityEngine;
using VRC.SDKBase;
using VRC.Udon;
using UnityEngine;

public class MaterialToggle : UdonSharpBehaviour 
{
	public Material[] materialList;
	public string propName;
	public bool defaultOn;
	public bool global;
	
	private bool bNonGlobalToggle;
	
    [UdonSynced, FieldChangeCallback(nameof(SyncedToggle))]
	private bool currentlyOn;
	
	void Start()
	{
		bNonGlobalToggle = defaultOn;
		UpdateKeyword();
	}

    public bool SyncedToggle
    {
        set
        {
            currentlyOn = value;
			UpdateKeyword();
        }
        get => currentlyOn;
    }


	public void UpdateKeyword()
	{
		bool bOn = bNonGlobalToggle;
		if( global )
		{
			bOn = SyncedToggle;
			if( defaultOn ) bOn = !bOn;
		}
		foreach( Material m in materialList )
		{
			if( m != null )
			{
				if( bOn )
					m.EnableKeyword( propName );
				else
					m.DisableKeyword( propName );
			}
		}
	}

	public override void Interact()
	{
		currentlyOn = !currentlyOn;
		bNonGlobalToggle = !bNonGlobalToggle;
		UpdateKeyword();
		if( global )
		{
			RequestSerialization();
	        Networking.SetOwner(Networking.LocalPlayer, gameObject);
		}
	}
}
