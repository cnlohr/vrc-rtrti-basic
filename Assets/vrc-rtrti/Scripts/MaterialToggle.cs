
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
	
    [UdonSynced, FieldChangeCallback(nameof(SyncedToggle))]
	public bool currentlyOn;
	
	void Start()
	{
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
		bool bOn = SyncedToggle;
		if( defaultOn ) bOn = !bOn;
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
        Networking.SetOwner(Networking.LocalPlayer, gameObject);
		UpdateKeyword();
		RequestSerialization();
	}
}
