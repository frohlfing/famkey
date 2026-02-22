using Privault.Core.Models.Entities;
using Privault.Core.ViewModels;

namespace Privault.Tests.ViewModels;

/// <summary>
/// Tests für das <see cref="DetailFriendViewModel"/>.
/// </summary>
public class DetailFriendViewModelTests
{
    /// <summary>
    /// 1.1.1 LevelChange: Änderung des Access-Levels muss den Callback triggern.
    /// </summary>
    [Fact]
    public void LevelChange_ShouldTriggerCallback()
    {
        // Arrange
        var callbackCalled = false;
        var vm = new DetailFriendViewModel 
        { 
            User = new UserEntity { Name = "Bob" },
            // ReSharper disable once UnusedParameter.Local
            OnChanged = (item) => callbackCalled = true 
        };

        // Act
        vm.AccessLevel = 2;

        // Assert
        Assert.True(callbackCalled);
    }
}