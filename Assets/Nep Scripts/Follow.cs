
using UdonSharp;
using UnityEngine;
using VRC.SDKBase;
using VRC.Udon;

public class Follow : UdonSharpBehaviour
{
    public VRCPlayerApi _player;
    public float heightOffset = 0.4f;
    private float currentHeight = 0f;
    public bool Copyispresent = false;
    public float smoothTime = 0.2f;
    private Vector3 Dummy = new Vector3();

    void Start()
    {
        _player = Networking.LocalPlayer;
    }
    void OnPlayerJoined (VRCPlayerApi GayDitto)
    {
        //Debug.Log("playername "+GayDitto.displayName);
        if (string.Equals("Copyrighted",GayDitto.displayName))
        {
            _player = GayDitto;
            Copyispresent = true;
            //Debug.Log("Copy Joined");
        }
    }
        void OnPlayerLeft (VRCPlayerApi GayDitto)
    {
        if (string.Equals("Copyrighted",GayDitto.displayName))
        {
            _player = null;
            Copyispresent = false;
        }
    }
    private void LateUpdate()
    {
        if (Copyispresent)
        {
        currentHeight = _player.GetTrackingData(VRCPlayerApi.TrackingDataType.Head).position.y;
        currentHeight = currentHeight + heightOffset;
        Vector3 Target = new Vector3(_player.GetPosition().x, currentHeight, _player.GetPosition().z);
        transform.position = Vector3.SmoothDamp(transform.position, Target, ref Dummy, smoothTime);
        transform.rotation = _player.GetRotation();
        }
    }
}
